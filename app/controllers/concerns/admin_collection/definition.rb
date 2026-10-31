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

    # Tables whose changes should invalidate the ETag (count + max updated_at).
    def etag_sources(*models)
      @etag_models = [model, *models].uniq
    end
  end
end
