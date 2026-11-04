# frozen_string_literal: true

module AdminCollection
  # One parsed request against a Definition. Parsing happens in the
  # constructor and raises InvalidQuery, so nothing reaches the database
  # until every parameter has been checked.
  class Query
    attr_reader :page, :per, :fields, :facets

    def initialize(definition, params)
      @definition = definition
      @params = params
      @filters = parse_filters
      @order = parse_sort
      @fields = parse_fields
      @facets = parse_facets
      @page, @per = parse_paging
    end

    # Rows matching q and every filter, unordered.
    def filtered
      @filtered ||= apply_filters(search_scope)
    end

    def rows
      scope = filtered.order(@order).limit(per).offset((page - 1) * per)
      select_fields(scope).map { |record| serialize(record) }
    end

    def meta(total)
      { total: total, page: page, per: per, total_pages: (total / per.to_f).ceil }
    end

    # Each facet ignores its own filter so the other values of a multi-select
    # stay visible; q and the remaining filters still apply.
    def facet_counts
      facets.index_with do |name|
        scope = apply_filters(search_scope, except: name)
        config = @definition.facets[name]
        counts = if config[:through] then through_counts(scope, config)
                 elsif config[:column].is_a?(Array) then multi_column_counts(scope, config[:column])
                 else scope.group(config[:column]).count
                 end
        values = enum_values(config)
        counts = counts.transform_keys { |k| values.fetch(k, k) } if values
        counts.transform_keys { |k| k.nil? ? NONE : k.to_s }
      end
    end

    private

    # ---- parsing -----------------------------------------------------------

    def param_hash(key)
      raw = @params[key]
      return {} if raw.blank?
      raise InvalidQuery, "#{key} must be an object, e.g. #{key}[name]=value" unless raw.is_a?(ActionController::Parameters)

      # Keys are checked against the allowlist; nothing is mass-assigned.
      raw.to_unsafe_h
    end

    # [[filter_name, ->(scope) { ... }], ...]
    def parse_filters
      Filters.parse(@definition, param_hash(:filter))
    end

    def parse_sort
      keys = @params[:sort].present? ? AdminCollection.csv(@params[:sort]) : @definition.default_sort
      table = @definition.model.arel_table
      order = keys.uniq.map do |key|
        name = key.delete_prefix('-')
        column = @definition.sorts[name]
        raise InvalidQuery, "Unknown sort: #{name}" unless column

        # A sql sort's expression is written in the controller, never user input
        node = column.is_a?(Hash) ? Arel::Nodes::Grouping.new(Arel.sql(column[:sql])) : table[column]
        (key.start_with?('-') ? Arel::Nodes::Descending : Arel::Nodes::Ascending).new(node).nulls_last
      end
      order << table[:id].asc
    end

    def parse_fields
      return @definition.default_fields if @params[:fields].blank?

      names = AdminCollection.csv(@params[:fields])
      unknown = names - @definition.fields.keys
      raise InvalidQuery, "Unknown field: #{unknown.join(', ')}" if unknown.any?

      ['id', *names].uniq
    end

    def parse_facets
      names = AdminCollection.csv(@params[:facets]).uniq
      unknown = names - @definition.facets.keys
      raise InvalidQuery, "Unknown facet: #{unknown.join(', ')}" if unknown.any?

      names
    end

    def parse_paging
      page = [@params[:page].to_i, 1].max
      per = @params[:per].to_i
      per = DEFAULT_PER if per <= 0
      [page, [per, MAX_PER].min]
    end

    # ---- querying ----------------------------------------------------------

    def search_scope
      scope = @definition.model.all
      q = @params[:q].to_s.strip
      return scope if q.empty? || @definition.search_columns.empty?

      pattern = "%#{@definition.model.sanitize_sql_like(q)}%"
      table = @definition.model.arel_table
      scope.where(@definition.search_columns.map { |c| table[c].matches(pattern) }.reduce(:or))
    end

    def apply_filters(scope, except: nil)
      @filters.reduce(scope) { |s, (name, apply)| name == except ? s : apply.call(s) }
    end

    # Associated rows per value among the scope's rows; rows with none count
    # under nil, so a row in two series counts once under each.
    def through_counts(scope, config)
      through = config[:through]
      owners = scope.select(through[:owner_key])
      counts = through[:model].where(through[:key] => owners).group(config[:column]).count
      unlinked = scope.where.not(through[:owner_key] => through[:model].select(through[:key])).count
      unlinked.positive? ? counts.merge(nil => unlinked) : counts
    end

    # Rows per value across several columns (a row whose columns repeat a
    # value counts once); rows where every column is NULL count under nil.
    def multi_column_counts(scope, columns)
      model = @definition.model
      table = model.arel_table
      pairs = columns.map { |c| scope.unscope(:select).select(table[:id], table[c].as('facet_value')).to_sql }
      sql = "SELECT facet_value, COUNT(*) FROM (#{pairs.join(' UNION ')}) AS facet_pairs " \
            'WHERE facet_value IS NOT NULL GROUP BY facet_value'
      counts = model.connection.select_rows(sql).to_h { |value, count| [value, count.to_i] }
      empty = scope.where(columns.index_with(nil)).count
      empty.positive? ? counts.merge(nil => empty) : counts
    end

    # An integer facet on an enum column counts under the stored integers;
    # Rails groups enums by name.
    def enum_values(config)
      return unless config[:type] == :integer && config[:column].is_a?(String)

      @definition.model.defined_enums[config[:column]]
    end

    def field_config(name) = @definition.fields[name]

    def select_fields(scope)
      includes = fields.filter_map { |f| field_config(f)[:includes] }.uniq
      scope = scope.includes(*includes) if includes.any?

      selects = fields.filter_map { |f| select_node(f) }
      selects.any? ? scope.select(@definition.model.arel_table[Arel.star], *selects) : scope
    end

    # A declared select subquery as `(<sql>) AS "<field>"`. The SQL is written in
    # the controller's admin_collection block; the field name was checked against
    # the declared fields in parse_fields.
    def select_node(name)
      sql = field_config(name)[:select]
      return unless sql

      alias_name = Arel.sql(@definition.model.connection.quote_column_name(name))
      Arel::Nodes::As.new(Arel::Nodes::Grouping.new(Arel.sql(sql)), alias_name)
    end

    def serialize(record)
      fields.index_with do |name|
        config = field_config(name)
        if config[:value] then config[:value].call(record)
        elsif config[:select] then record[name]
        else record[config[:column]]
        end
      end
    end
  end
end
