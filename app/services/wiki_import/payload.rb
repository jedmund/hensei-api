# frozen_string_literal: true

module WikiImport
  ##
  # The shape check for a POST /import/wiki body. It only checks types and
  # sizes; whether a title, key, bullet or class exists is the importer's job,
  # and unknown values there become warnings, never errors.
  #
  # Multi-word keys are read in camelCase or snake_case (`fullAutoOff` or
  # `full_auto_off`): the web's API adapter snake_cases request bodies.
  class Payload
    class Invalid < StandardError; end

    KEY_GROUPS = %w[opus ultima draconic destroyer ccw].freeze
    MAX_ITEMS = 20
    MAX_BULLETS = 10
    MAX_KEYS = 4
    MAX_STRING = 200

    Item = Struct.new(:position, :title, :uncap, :awakening, :ring, :full_auto_off, keyword_init: true)
    Job = Struct.new(:name, :accessory, :skills, :full_auto_off, keyword_init: true)

    attr_reader :preview, :job, :bullets, :characters, :weapons, :summons, :key_sets, :quick

    ##
    # @param body [Object] the parsed JSON body.
    # @return [Payload]
    # @raise [Invalid] when the body has the wrong shape.
    def self.parse(body)
      new(body)
    end

    def initialize(body)
      raise Invalid, 'body must be an object' unless body.is_a?(Hash)

      wiki = body['wiki']
      raise Invalid, 'wiki must be an object' unless wiki.is_a?(Hash)

      @preview = parse_preview(wiki)
      @job = parse_job(wiki['job'])
      @bullets = string_list(wiki['bullets'], 'bullets', MAX_BULLETS, allow_nil_entries: false)
      @characters = parse_items(wiki['characters'], 'characters', character: true)
      @weapons = parse_items(wiki['weapons'], 'weapons')
      @summons = parse_items(wiki['summons'], 'summons')
      @key_sets = parse_keys(wiki['keys'])
      @quick = optional_integer(wiki['quick'], 'quick')
    end

    private

    # Preview is the safe default when the flag is left out.
    def parse_preview(wiki)
      return true unless wiki.key?('preview')

      value = wiki['preview']
      raise Invalid, 'preview must be a boolean' unless [true, false].include?(value)

      value
    end

    def parse_job(value)
      return nil if value.nil?
      raise Invalid, 'job must be an object' unless value.is_a?(Hash)

      Job.new(
        name: optional_string(value['name'], 'job.name'),
        accessory: optional_string(value['accessory'], 'job.accessory'),
        skills: string_list(value['skills'], 'job.skills', 3, allow_nil_entries: true),
        full_auto_off: integer_list(camel(value, 'fullAutoOff'), 'job.fullAutoOff')
      )
    end

    def parse_items(value, field, character: false)
      return [] if value.nil?
      raise Invalid, "#{field} must be an array" unless value.is_a?(Array)
      raise Invalid, "#{field} has too many entries" if value.length > MAX_ITEMS

      value.each_with_index.map do |entry, index|
        name = "#{field}[#{index}]"
        raise Invalid, "#{name} must be an object" unless entry.is_a?(Hash)

        position = entry['position']
        raise Invalid, "#{name}.position must be an integer" unless position.is_a?(Integer)

        title = entry['title']
        raise Invalid, "#{name}.title must be a string" unless title.is_a?(String)
        raise Invalid, "#{name}.title is too long" if title.length > MAX_STRING

        Item.new(
          position: position,
          title: title,
          uncap: optional_string(entry['uncap'], "#{name}.uncap"),
          awakening: optional_string(entry['awakening'], "#{name}.awakening"),
          ring: character ? optional_boolean(entry['ring'], "#{name}.ring") : false,
          full_auto_off: character ? integer_list(camel(entry, 'fullAutoOff'), "#{name}.fullAutoOff") : []
        )
      end
    end

    def parse_keys(value)
      return {} if value.nil?
      raise Invalid, 'keys must be an object' unless value.is_a?(Hash)

      value.each_with_object({}) do |(group, ids), memo|
        raise Invalid, "keys.#{group} must be an array" unless ids.is_a?(Array)
        raise Invalid, "keys.#{group} has too many entries" if ids.length > MAX_KEYS
        unless ids.all? { |id| id.nil? || id.is_a?(Integer) }
          raise Invalid, "keys.#{group} must hold integers or null"
        end

        memo[group.to_s] = ids
      end
    end

    # The camelCase key, or its snake_case spelling.
    def camel(hash, key)
      hash.key?(key) ? hash[key] : hash[key.underscore]
    end

    def optional_string(value, field)
      return nil if value.nil?
      raise Invalid, "#{field} must be a string" unless value.is_a?(String)
      raise Invalid, "#{field} is too long" if value.length > MAX_STRING

      value
    end

    def optional_boolean(value, field)
      return false if value.nil?
      raise Invalid, "#{field} must be a boolean" unless [true, false].include?(value)

      value
    end

    def optional_integer(value, field)
      return nil if value.nil?
      raise Invalid, "#{field} must be an integer" unless value.is_a?(Integer)

      value
    end

    def string_list(value, field, max, allow_nil_entries:)
      return [] if value.nil?
      raise Invalid, "#{field} must be an array" unless value.is_a?(Array)
      raise Invalid, "#{field} has too many entries" if value.length > max

      value.each_with_index.map do |entry, index|
        next nil if entry.nil? && allow_nil_entries

        optional_string(entry, "#{field}[#{index}]") || raise(Invalid, "#{field}[#{index}] must be a string")
      end
    end

    def integer_list(value, field)
      return [] if value.nil?
      raise Invalid, "#{field} must be an array" unless value.is_a?(Array)
      raise Invalid, "#{field} has too many entries" if value.length > 4
      raise Invalid, "#{field} must hold integers" unless value.all?(Integer)

      value
    end
  end
end
