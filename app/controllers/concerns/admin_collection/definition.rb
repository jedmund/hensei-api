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
    end

    # Columns matched by `q` (case-insensitive substring).
    def search(*columns)
      @search_columns.concat(columns.map(&:to_s))
    end

    # A column filter. type: :integer, :string, :uuid, :date, :datetime or
    # :boolean. `resolve` maps raw list values to column values (e.g. slugs to
    # ids). `facet: true` also makes it a facet.
    def filter(name, type:, column: name, resolve: nil, facet: false)
      @filters[name.to_s] = { type: type, column: column.to_s, resolve: resolve }
      @facets[name.to_s] = column.to_s if facet
    end

    # A foreign-key filter that accepts ids or slugs of `references`.
    # Values matching no row are a 422.
    def reference_filter(name, references:, column:, slug: :slug, facet: false)
      label = name.to_s.humanize(capitalize: false)
      resolve = lambda do |values|
        values = values.map { |v| v.match?(UUID_FORMAT) ? v.downcase : v }
        ids, slugs = values.partition { |v| v.match?(UUID_FORMAT) }
        found = references.where(id: ids).or(references.where(slug => slugs)).pluck(:id, slug)
        unknown = values - found.flatten.map(&:to_s)
        raise InvalidQuery, "unknown #{label}: #{unknown.join(', ')}" if unknown.any?

        found.map(&:first)
      end
      filter(name, type: :uuid, column: column, resolve: resolve, facet: facet)
    end

    # A boolean filter backed by a SQL condition written here (never user
    # input). =true keeps matching rows, =false the rest.
    def flag(name, sql)
      @filters[name.to_s] = { type: :flag, sql: sql }
    end

    def sort(*names)
      names.each { |name| @sorts[name.to_s] = name.to_s }
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
  end
end
