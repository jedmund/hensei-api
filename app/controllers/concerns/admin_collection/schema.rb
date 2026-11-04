# frozen_string_literal: true

module AdminCollection
  # What a resource can do, as JSON for the database editor
  # (GET /admin/:resource/schema). Built from the Definition, the controller's
  # PERMITTED list and the model's validators, so nothing is restated here.
  # The web app owns labels and layout; this only says what may be searched,
  # filtered, sorted, returned and written, the enum values, and the simple
  # validation rules.
  #
  # Validator rules are published only for the kinds below; custom `validate`
  # methods aren't introspectable and stay server-side. Format patterns are
  # JavaScript RegExp source (\A and \z become ^ and $).
  class Schema
    VALIDATOR_KINDS = %i[presence absence format inclusion exclusion numericality uniqueness length].freeze
    COMMON_OPTIONS = %i[allow_nil allow_blank].freeze
    NUMERICALITY_OPTIONS = %i[only_integer greater_than greater_than_or_equal_to less_than
                              less_than_or_equal_to equal_to other_than odd even].freeze
    LENGTH_OPTIONS = %i[minimum maximum is].freeze

    def initialize(definition)
      @definition = definition
    end

    def to_h
      {
        search: @definition.search_columns,
        filters: filters,
        flags: @definition.filters.select { |_, config| config[:type] == :flag }.keys,
        sorts: @definition.sorts.keys,
        default_sort: @definition.default_sort,
        fields: @definition.fields.keys,
        default_fields: @definition.default_fields,
        writable: writable,
        enums: @definition.enums.to_h { |name, values| [name.to_s, values.transform_keys(&:to_s)] },
        validators: validators
      }
    end

    private

    # Mirrors Query#list_filter and #range_filter: which filters take a list
    # (filter[x]=a,b) and which a range (filter[x][gte]=...).
    def filters
      @definition.filters.reject { |_, config| config[:type] == :flag }.to_h do |name, config|
        entry = {
          type: config[:type].to_s,
          facet: @definition.facets.key?(name),
          list: config[:type] != :boolean && (config[:resolve].present? || Filters::LIST_TYPES.include?(config[:type])),
          range: Filters::RANGE_TYPES.include?(config[:type])
        }
        entry[:reference] = config[:reference] if config[:reference]
        [name, entry]
      end
    end

    # permit() arguments as { name => "scalar" | "array" | "hash" }.
    def writable
      @definition.writable.each_with_object({}) do |entry, out|
        next out[entry.to_s] = 'scalar' unless entry.is_a?(Hash)

        entry.each do |name, shape|
          out[name.to_s] = case shape
                           when [] then 'array'
                           when {} then 'hash'
                           else raise ArgumentError, "unsupported permit shape for #{name}: #{shape.inspect}"
                           end
        end
      end
    end

    def validators
      @definition.model.validators.each_with_object({}) do |validator, out|
        next unless VALIDATOR_KINDS.include?(validator.kind)

        rule = validator_rule(validator)
        next unless rule

        validator.attributes.each { |attribute| (out[attribute.to_s] ||= []) << rule }
      end
    end

    def validator_rule(validator)
      options = validator.options
      rule = { kind: validator.kind.to_s }
      rule[:on] = Array(options[:on]).map(&:to_s) if options[:on]
      rule[:conditional] = true if options[:if] || options[:unless]

      details = case validator.kind
                when :format then format_rule(options)
                when :inclusion, :exclusion then values_rule(options)
                when :numericality then literal_options(options, NUMERICALITY_OPTIONS)
                when :length then literal_options(options, LENGTH_OPTIONS)
                else {}
                end
      return unless details

      rule.merge(details, literal_options(options, COMMON_OPTIONS))
    end

    def format_rule(options)
      regexp = options[:with]
      return unless regexp.is_a?(Regexp)

      { pattern: javascript_source(regexp), flags: regexp.casefold? ? 'i' : '' }
    end

    def javascript_source(regexp)
      if regexp.options.anybits?(Regexp::MULTILINE | Regexp::EXTENDED)
        raise ArgumentError, "#{regexp.inspect} uses options with no JavaScript equivalent"
      end

      source = regexp.source.sub(/\A\\A/, '^').sub(/\\z\z/, '$')
      raise ArgumentError, "#{regexp.inspect} has Ruby-only anchors" if source.match?(/\\[AzZ]/)

      source
    end

    def values_rule(options)
      values = options[:in] || options[:within]
      case values
      when Range then { minimum: values.begin, maximum: values.end, exclude_end: values.exclude_end? }.compact
      when Enumerable then { in: values.to_a }
      end
    end

    # Only plain values: procs and method names are evaluated per record.
    def literal_options(options, keys)
      options.slice(*keys).reject { |_, value| value.is_a?(Proc) || value.is_a?(Symbol) }
    end
  end
end
