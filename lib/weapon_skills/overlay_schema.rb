# frozen_string_literal: true

module WeaponSkills
  # Validates a curation overlay v2 document (docs/weapon-skill-pipeline/overlay-v2.md).
  # Returns a list of error strings; empty means valid.
  module OverlaySchema
    SECTIONS = %w[versions effects data ops].freeze
    OPS = %w[add_version remove_version gate description].freeze
    OVERRIDES = %w[modifier_override series_override size_override suppressed_boosts].freeze
    GATE_FIELDS = %w[unlock_level min_uncap transcendence_stage].freeze

    module_function

    def validate(doc)
      return ["document must be an object"] unless doc.is_a?(Hash)

      errors = []
      errors << "format must be 2" unless doc["format"] == 2
      unknown = doc.keys - SECTIONS - %w[format _generated]
      errors << "unknown sections: #{unknown.join(', ')}" if unknown.any?
      SECTIONS.each do |section|
        entries = doc.fetch(section, [])
        next errors << "#{section} must be an array" unless entries.is_a?(Array)

        entries.each_with_index { |entry, i| errors.concat(entry_errors(section, entry).map { |e| "#{section}[#{i}]: #{e}" }) }
      end
      errors
    end

    def entry_errors(section, entry)
      return ["must be an object"] unless entry.is_a?(Hash)

      case section
      when "versions" then version_errors(entry)
      when "effects", "data" then row_errors(entry)
      when "ops" then op_errors(entry)
      end
    end

    def version_errors(entry)
      errors = reference_errors(entry, required: true) + stamp_errors(entry)
      errors << "needs at least one of #{OVERRIDES.join(', ')}" unless entry.keys.intersect?(OVERRIDES)
      if entry.key?("suppressed_boosts") && !entry["suppressed_boosts"].is_a?(Array)
        errors << "suppressed_boosts must be an array"
      end
      errors
    end

    def row_errors(entry)
      errors = stamp_errors(entry)
      errors << "boost_type is required" if entry["boost_type"].blank?
      errors << "modifier is required" if entry["modifier"].blank?
      canonical = entry["weapon"].nil? && entry["skill"].nil?
      errors.concat(reference_errors(entry, required: true)) unless canonical
      errors
    end

    def op_errors(entry)
      op = entry["op"]
      return ["op must be one of #{OPS.join(', ')}"] unless OPS.include?(op)

      errors = reference_errors(entry, required: true) + stamp_errors(entry)
      errors << "reason is required (cite the wiki page or capture)" if entry["reason"].blank?
      case op
      when "add_version"
        errors << "position must be an integer" unless entry["position"].is_a?(Integer)
        errors << "min_uncap must be an integer" unless entry["min_uncap"].is_a?(Integer)
      when "gate"
        given = GATE_FIELDS & entry.keys
        errors << "gate needs at least one of #{GATE_FIELDS.join(', ')}" if given.empty?
        given.each { |f| errors << "#{f} must be an integer or null" unless entry[f].nil? || entry[f].is_a?(Integer) }
      when "description"
        errors << "description needs description_en or description_jp" unless %w[description_en description_jp].intersect?(entry.keys)
      end
      errors
    end

    def reference_errors(entry, required:)
      return [] unless required

      errors = []
      errors << "weapon must be a granblue_id string" unless entry["weapon"].is_a?(String) && entry["weapon"].match?(/\A\d+\z/)
      errors << "skill is required" if entry["skill"].blank?
      errors << "ordinal must be an integer" unless entry["ordinal"].is_a?(Integer)
      errors
    end

    def stamp_errors(entry)
      Time.iso8601(entry["edited_at"].to_s)
      []
    rescue ArgumentError
      ["edited_at must be an ISO 8601 time"]
    end
  end
end
