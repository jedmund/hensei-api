# frozen_string_literal: true

module AdminCollection
  # Parses a request's filter[...] params against a Definition's filters
  # into scope lambdas, raising InvalidQuery for anything unknown or
  # malformed. Query applies them.
  class Filters
    LIST_TYPES = %i[integer string uuid date].freeze
    RANGE_TYPES = %i[integer date datetime].freeze

    # @param definition [Definition]
    # @param raw_filters [Hash] filter name => raw value (a list, a range hash or a flag)
    # @return [Array<Array(String, Proc)>] [[filter_name, ->(scope) { ... }], ...]
    # @raise [InvalidQuery]
    def self.parse(definition, raw_filters)
      new(definition).parse(raw_filters)
    end

    def initialize(definition)
      @definition = definition
    end

    def parse(raw_filters)
      raw_filters.map do |name, raw|
        config = @definition.filters[name.to_s]
        raise InvalidQuery, "Unknown filter: #{name}" unless config

        [name.to_s, build_filter(name, config, raw)]
      end
    end

    private

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

      raw_values = raw.is_a?(Array) ? raw.flat_map { |v| AdminCollection.csv(v) } : AdminCollection.csv(raw)
      raise InvalidQuery, "filter[#{name}] needs at least one value" if raw_values.empty?

      include_null = raw_values.delete(NONE).present?
      values = if config[:resolve]
                 config[:resolve].call(raw_values)
               else
                 raw_values.map { |v| cast(name, config[:type], v) }
               end
      values << nil if include_null
      match(config, values)
    end

    def range_filter(name, config, raw)
      raise InvalidQuery, "filter[#{name}] does not take a range" unless RANGE_TYPES.include?(config[:type])
      raise InvalidQuery, "filter[#{name}] accepts only gte and lte" if raw.empty? || (raw.keys.map(&:to_s) - %w[gte lte]).any?

      gte = raw['gte'].presence && cast(name, config[:type], raw['gte'])
      lte = raw['lte'].presence && cast(name, config[:type], raw['lte'], upper: true)
      raise InvalidQuery, "filter[#{name}] needs gte or lte" if gte.nil? && lte.nil?

      match(config, gte..lte)
    end

    # A scope lambda keeping rows whose column (any of several columns, or any
    # associated row's column) is in `values` (an array, nil meaning NULL or
    # no associated row) or within a range.
    def match(config, values)
      return through_match(config[:through], config[:column], values) if config[:through]

      columns = config[:column]
      return ->(scope) { scope.where(columns => values) } unless columns.is_a?(Array)

      table = @definition.model.arel_table
      ->(scope) { scope.where(columns.map { |c| column_match(table[c], values) }.reduce(:or)) }
    end

    def column_match(attribute, values)
      return attribute.between(values) if values.is_a?(Range)

      present = values.compact
      clauses = []
      clauses << attribute.in(present) if present.any?
      clauses << attribute.eq(nil) if values.include?(nil)
      clauses.reduce(:or)
    end

    def through_match(through, column, values)
      owner_key = through[:owner_key]
      linked = through[:model].select(through[:key])
      lambda do |scope|
        present = values.is_a?(Range) ? values : values.compact
        matched = scope.where(owner_key => linked.where(column => present))
        next matched unless values.is_a?(Array) && values.include?(nil)

        unlinked = scope.where.not(owner_key => linked)
        present.empty? ? unlinked : matched.or(unlinked)
      end
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
  end
end
