# frozen_string_literal: true

module AdminCollection
  # What a resource allows. Built by the block given to `admin_collection`.
  class Definition
    attr_reader :model, :search_columns, :filters, :sorts, :fields, :facets, :etag_models

    def initialize(model)
      @model = model
      @search_columns = []
      @filters = {}
      @sorts = {}
      @fields = { 'id' => { column: 'id' } }
      @facets = {}
      @default_fields = []
      @default_sort = []
      @etag_models = [model]
      @writable = []
      @enums = {}
    end

    # Columns matched by `q` (case-insensitive substring).
    def search(*columns)
      @search_columns.concat(columns.map(&:to_s))
    end

    # A column filter. type: :integer, :string, :uuid, :date, :datetime or
    # :boolean. An :integer filter on an enum column (e.g. Event#element) takes
    # and facets the stored integers, not the enum's names. `resolve` maps raw list values to column values (e.g. slugs to
    # ids). `facet: true` also makes it a facet.
    #
    # `column` may list several columns: a row matches when any of them does
    # (e.g. a primary or secondary proficiency), and "none" means all are NULL.
    #
    # `through` names a has_many association whose rows hold `column` (e.g. a
    # join table). A row matches when any associated row does, "none" means it
    # has no associated rows, and facets count associated rows per value.
    def filter(name, type:, column: name, resolve: nil, facet: false, through: nil)
      columns = Array(column).map(&:to_s)
      config = { type: type, column: columns.one? ? columns.first : columns, resolve: resolve }
      config[:through] = through_config(through) if through
      @filters[name.to_s] = config
      @facets[name.to_s] = config.slice(:type, :column, :through) if facet
    end

    # A foreign-key filter that accepts ids or slugs of `references`.
    # Values matching no row are a 422. With `through`, the key lives on the
    # associated rows (see `filter`).
    def reference_filter(name, references:, column:, slug: :slug, facet: false, through: nil)
      label = name.to_s.humanize(capitalize: false)
      resolve = lambda do |values|
        values = values.map { |v| v.match?(UUID_FORMAT) ? v.downcase : v }
        ids, slugs = values.partition { |v| v.match?(UUID_FORMAT) }
        found = references.where(id: ids).or(references.where(slug => slugs)).pluck(:id, slug)
        unknown = values - found.flatten.map(&:to_s)
        raise InvalidQuery, "unknown #{label}: #{unknown.join(', ')}" if unknown.any?

        found.map(&:first)
      end
      filter(name, type: :uuid, column: column, resolve: resolve, facet: facet, through: through)
      @filters[name.to_s][:reference] = references.table_name
    end

    # A boolean filter backed by a SQL condition written here (never user
    # input). =true keeps matching rows, =false the rest.
    def flag(name, sql)
      @filters[name.to_s] = { type: :flag, sql: sql }
    end

    # Sortable columns. `sql` instead sorts one name by a scalar SQL
    # expression written here (never user input), e.g. a correlated subquery
    # reading a parent row.
    def sort(*names, sql: nil)
      raise ArgumentError, 'a sql sort takes one name' if sql && names.many?

      names.each { |name| @sorts[name.to_s] = sql ? { sql: sql } : name.to_s }
    end

    # A returned field. Plain columns need only the name; `value` computes from
    # the record, `includes` preloads what it reads, and `select` adds a SQL
    # expression (aliased to the field name) to the query.
    def field(name, column: name, value: nil, includes: nil, select: nil)
      @fields[name.to_s] = { column: column.to_s, value: value, includes: includes, select: select }
    end

    def default_fields(*names)
      return @default_fields if names.empty?

      @default_fields = ['id', *names.map(&:to_s)].uniq
    end

    def default_sort(*names)
      return @default_sort if names.empty?

      @default_sort = names.map(&:to_s)
    end

    # What create and update accept: the controller's permit() list (its
    # PERMITTED constant), published by the schema.
    def writable(permitted = nil)
      return @writable if permitted.nil?

      @writable = permitted
    end

    # Value maps ({ name => value }) for enum-valued columns, published by the
    # schema. Pass the same constants the model validates against.
    def enums(**maps)
      return @enums if maps.empty?

      @enums = @enums.merge(maps)
    end

    # The JSON the schema endpoint serves. Static per deploy, so it's built
    # once (on first use, after the model's validators are declared).
    def schema
      @schema ||= Schema.new(self).to_h.freeze
    end

    def schema_digest
      @schema_digest ||= Digest::SHA256.hexdigest(schema.to_json)
    end

    # Other tables whose changes should invalidate the ETag: model classes or
    # association names on the model. Each contributes its row count and, if
    # it has one, max(updated_at). Bulk writers to these tables (update_all,
    # update_columns, raw SQL) must set updated_at themselves, or revisits
    # get a stale 304.
    def etag_sources(*sources)
      models = sources.map do |source|
        next source unless source.is_a?(Symbol) || source.is_a?(String)

        reflection = model.reflect_on_association(source)
        raise ArgumentError, "#{model} has no association #{source}" unless reflection

        reflection.klass
      end
      @etag_models = [model, *models].uniq
    end

    private

    # { model:, key:, owner_key: }: rows of `model` whose `key` equals the
    # collection row's `owner_key`. The association's own scope is not applied.
    def through_config(association)
      reflection = model.reflect_on_association(association)
      unless reflection&.collection? && !reflection.through_reflection?
        raise ArgumentError, "#{model} has no direct has_many #{association}"
      end

      { model: reflection.klass, key: reflection.foreign_key.to_s, owner_key: reflection.active_record_primary_key.to_s }
    end
  end
end
