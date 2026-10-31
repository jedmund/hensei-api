# frozen_string_literal: true

module AdminCollection
  # One parsed request against a Definition. Parsing happens in the
  # constructor and raises InvalidQuery, so nothing reaches the database
  # until every parameter has been checked.
  class Query
    LIST_TYPES = %i[integer string uuid date].freeze
    RANGE_TYPES = %i[integer date datetime].freeze

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
        apply_filters(search_scope, except: name)
          .group(@definition.facets[name]).count
          .transform_keys { |k| k.nil? ? NONE : k.to_s }
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

    def csv(value)
      value.to_s.split(',').map(&:strip).compact_blank
    end

    # [[filter_name, ->(scope) { ... }], ...]
    def parse_filters
      param_hash(:filter).map do |name, raw|
        config = @definition.filters[name.to_s]
        raise InvalidQuery, "Unknown filter: #{name}" unless config

        [name.to_s, build_filter(name, config, raw)]
      end
    end

    def build_filter(name, config, raw)
      case config[:type]
      when :flag then flag_filter(name, config, raw)
      when :boolean then boolean_filter(name, config, raw)
      else raw.is_a?(Hash) ? range_filter(name, config, raw) : list_filter(name, config, raw)
      end
    end

    def boolean(name, raw)
      case raw.to_s
      when 'true' then true
      when 'false' then false
      else raise InvalidQuery, "filter[#{name}] must be true or false"
      end
    end

    def flag_filter(name, config, raw)
      sql = Arel.sql(config[:sql])
      boolean(name, raw) ? ->(scope) { scope.where(sql) } : ->(scope) { scope.where.not(sql) }
    end

    def boolean_filter(name, config, raw)
      condition = { config[:column] => boolean(name, raw) }
      ->(scope) { scope.where(condition) }
    end

    def list_filter(name, config, raw)
      raise InvalidQuery, "filter[#{name}] takes a range, not a list" unless config[:resolve] || LIST_TYPES.include?(config[:type])

      raw_values = raw.is_a?(Array) ? raw.flat_map { |v| csv(v) } : csv(raw)
      raise InvalidQuery, "filter[#{name}] needs at least one value" if raw_values.empty?

      include_null = raw_values.delete(NONE).present?
      values = if config[:resolve]
                 config[:resolve].call(raw_values)
               else
                 raw_values.map { |v| cast(name, config[:type], v) }
               end
      values << nil if include_null
      condition = { config[:column] => values }
      ->(scope) { scope.where(condition) }
    end

    def range_filter(name, config, raw)
      raise InvalidQuery, "filter[#{name}] does not take a range" unless RANGE_TYPES.include?(config[:type])
      raise InvalidQuery, "filter[#{name}] accepts only gte and lte" if raw.empty? || (raw.keys.map(&:to_s) - %w[gte lte]).any?

      gte = raw['gte'].presence && cast(name, config[:type], raw['gte'])
      lte = raw['lte'].presence && cast(name, config[:type], raw['lte'], upper: true)
      raise InvalidQuery, "filter[#{name}] needs gte or lte" if gte.nil? && lte.nil?

      condition = { config[:column] => gte..lte }
      ->(scope) { scope.where(condition) }
    end

    def cast(name, type, value, upper: false)
      value = value.to_s
      case type
      when :integer then Integer(value, 10)
      when :string then value
      when :uuid then value.match?(UUID_FORMAT) ? value : raise(ArgumentError)
      when :date then Date.iso8601(value)
      when :datetime then cast_time(value, upper)
      end
    rescue ArgumentError, TypeError
      raise InvalidQuery, "Invalid value for filter[#{name}]: #{value}"
    end

    # Full ISO 8601 times are taken as is. A bare date covers the whole day,
    # so lte=2026-10-31 includes everything on the 31st.
    def cast_time(value, upper)
      return Time.iso8601(value) unless value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

      day = Time.zone.parse(Date.iso8601(value).to_s)
      upper ? day.end_of_day : day
    end

    def parse_sort
      keys = @params[:sort].present? ? csv(@params[:sort]) : @definition.default_sort
      table = @definition.model.arel_table
      order = keys.uniq.map do |key|
        name = key.delete_prefix('-')
        column = @definition.sorts[name]
        raise InvalidQuery, "Unknown sort: #{name}" unless column

        key.start_with?('-') ? table[column].desc.nulls_last : table[column].asc.nulls_last
      end
      order << table[:id].asc
    end

    def parse_fields
      return @definition.default_fields if @params[:fields].blank?

      names = csv(@params[:fields])
      unknown = names - @definition.fields.keys
      raise InvalidQuery, "Unknown field: #{unknown.join(', ')}" if unknown.any?

      ['id', *names].uniq
    end

    def parse_facets
      names = csv(@params[:facets]).uniq
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

    def field_config(name) = @definition.fields[name]

    def select_fields(scope)
      includes = fields.filter_map { |f| field_config(f)[:includes] }.uniq
      scope = scope.includes(*includes) if includes.any?

      selects = fields.filter_map { |f| field_config(f)[:select] && Arel.sql("(#{field_config(f)[:select]}) AS #{f}") }
      selects.any? ? scope.select(@definition.model.arel_table[Arel.star], *selects) : scope
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
