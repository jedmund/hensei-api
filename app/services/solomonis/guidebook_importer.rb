# frozen_string_literal: true

module Solomonis
  ##
  # Turns a guidebook log's `status_list` into guidebook entries for
  # Party#replace_solomonis_guide_effects!, matching effects by `status_id`.
  #
  # An unknown `status_id` adds a catalogue row from the entry, flagged
  # `needs_review`. Text with Japanese script goes in `name_jp`, anything else
  # in `name_en`; a known row gets its empty language filled (and flagged for
  # review) but never overwritten.
  #
  # Everything here is client-supplied, so entries are checked field by field;
  # malformed ones are skipped with a warning. Call #validate_size! first.
  class GuidebookImporter
    class TooManyEntries < StandardError; end

    MAX_ENTRIES = 300
    MAX_COUNT = 999
    MAX_TARGET_PARAM_LENGTH = 200
    MAX_ID = (2**31) - 1
    LINE_BREAK = '@@'
    VALUE_PLACEHOLDER = '{value}'
    JAPANESE_SCRIPT = /[\p{Hiragana}\p{Katakana}\p{Han}]/

    attr_reader :warnings

    # @param status_list [Array<Hash>]
    def initialize(status_list)
      @status_list = status_list
      @warnings = []
    end

    def self.validate_size!(status_list)
      raise TooManyEntries if status_list.size > MAX_ENTRIES
    end

    # Sum of `num` over well-formed counts, to check against the report's
    # spacebook_status_count.
    def stack_total
      @status_list.sum do |entry|
        entry.is_a?(Hash) && valid_status_id?(entry['status_id']) && valid_count?(entry['num']) ? entry['num'].to_i : 0
      end
    end

    # Writes catalogue rows for unknown effects and fills empty languages.
    #
    # @param previous [Hash{String => ExpeditionGuideEffect}] the run's current
    #   rows by effect ID, whose hand-entered fields carry over on re-import
    # @return [Array<Hash>] entries for Party#replace_solomonis_guide_effects!
    def call(previous: {})
      self.class.validate_size!(@status_list)
      entries = @status_list.each_with_index.filter_map { |raw, index| read_entry(raw, index) }
      entries = drop_repeats(entries)
      catalogue = SolomonisGuideEffect.where(granblue_id: entries.pluck(:status_id)).index_by(&:granblue_id)

      entries.filter_map do |entry|
        effect = catalogue[entry[:status_id]] ? update_effect(catalogue[entry[:status_id]], entry) : create_effect(entry)
        next unless effect

        guidebook_entry(effect, entry, previous[effect.id])
      end
    end

    private

    def read_entry(raw, index)
      unless raw.is_a?(Hash)
        @warnings << "Guidebook entry #{index + 1} isn't an object; skipped"
        return nil
      end

      status_id = raw['status_id']
      return skip(index, 'has no valid status_id') unless valid_status_id?(status_id)
      return skip(index, "(status #{status_id}) has no valid num") unless valid_count?(raw['num'])

      text = normalize_text(raw['name'])
      unless text && text.length <= SolomonisGuideEffect::NAME_MAX_LENGTH
        return skip(index, "(status #{status_id}) has no usable name")
      end

      { status_id: status_id, num: raw['num'].to_i, text: text, japanese: text.match?(JAPANESE_SCRIPT), raw: raw }
    end

    def skip(index, reason)
      @warnings << "Guidebook entry #{index + 1} #{reason}; skipped"
      nil
    end

    def drop_repeats(entries)
      entries.group_by { |e| e[:status_id] }.map do |status_id, group|
        @warnings << "Guidebook effect #{status_id} is listed #{group.size} times; kept the first" if group.size > 1
        group.first
      end
    end

    def valid_status_id?(value)
      value.is_a?(Integer) && value.between?(1, MAX_ID)
    end

    def valid_count?(value)
      int = value.is_a?(String) && value.match?(/\A\d{1,4}\z/) ? value.to_i : value
      int.is_a?(Integer) && int.between?(1, MAX_COUNT)
    end

    def normalize_text(value)
      return nil unless value.is_a?(String)

      value.gsub(LINE_BREAK, ' ').squish.presence
    end

    def update_effect(effect, entry)
      column = entry[:japanese] ? :name_jp : :name_en
      if effect[column].blank?
        effect.update!(column => entry[:text], needs_review: true)
        Rails.logger.info "[IMPORT][SOLOMONIS] Filled #{column} on guide effect #{effect.granblue_id}"
      end
      effect
    end

    def create_effect(entry)
      attributes = new_effect_attributes(entry)
      return nil unless attributes

      effect = SolomonisGuideEffect.new(attributes)
      unless effect.save
        @warnings << "Guidebook effect #{entry[:status_id]} couldn't be added (#{effect.errors.full_messages.to_sentence}); skipped"
        return nil
      end
      Rails.logger.info "[IMPORT][SOLOMONIS] Added guide effect #{entry[:status_id]} for review"
      effect
    end

    def new_effect_attributes(entry)
      raw = entry[:raw]
      rarity = SolomonisGuideEffect::GAME_RARITIES[raw['rarity']]
      return new_effect_skip(entry, 'has an unknown rarity') unless rarity

      stackable = parse_flag(raw['is_duplication_possible'])
      return new_effect_skip(entry, 'has no stackable flag') if stackable.nil?

      target = parse_target(entry)
      return nil unless target

      {
        granblue_id: entry[:status_id],
        rarity: rarity,
        stackable: stackable,
        (entry[:japanese] ? :name_jp : :name_en) => entry[:text],
        icon_category: small_int(raw['icon_category']),
        icon_type: small_int(raw['icon_type']),
        needs_review: true
      }.merge(target)
    end

    def new_effect_skip(entry, reason)
      @warnings << "New guidebook effect #{entry[:status_id]} #{reason}; skipped"
      nil
    end

    def parse_flag(value)
      case value
      when true, 1, '1' then true
      when false, 0, '0' then false
      end
    end

    def small_int(value)
      value.is_a?(Integer) && value.between?(0, MAX_ID) ? value : nil
    end

    # @return [Hash, nil] target_type, target_values, character_id; nil to skip
    def parse_target(entry)
      raw = entry[:raw]
      return { target_type: nil, target_values: [], character_id: nil } if raw['target_type'].nil?

      type = SolomonisGuideEffect::GAME_TARGET_TYPES[raw['target_type']]
      return new_effect_skip(entry, 'has an unknown target type') unless type

      param = raw['target_param'].to_s
      unless param.length <= MAX_TARGET_PARAM_LENGTH && param.match?(/\A\d{1,10}(_\d{1,10})*\z/)
        return new_effect_skip(entry, 'has an unreadable target')
      end

      values = param.split('_').map(&:to_i)
      return new_effect_skip(entry, 'has an out-of-range target') unless values.all? { |v| v <= MAX_ID }

      send(:"#{type}_target", entry, values)
    end

    def race_target(_entry, values)
      { target_type: 'race', target_values: values.uniq, character_id: nil }
    end

    # Weapon specialties arrive in the game's weapon kind numbering.
    def proficiency_target(entry, values)
      proficiencies = values.map { |kind| Granblue::GameIds.proficiency_for_weapon_kind(kind) }
      if proficiencies.any?(&:nil?)
        @warnings << "New guidebook effect #{entry[:status_id]} names an unknown weapon kind; dropped it"
      end
      { target_type: 'proficiency', target_values: proficiencies.compact.uniq, character_id: nil }
    end

    # The game's short character ID (Character.character_id), kept as sent
    # like the seed data; the character is resolved among route Evokers.
    def character_target(entry, values)
      character = Character.solomonis_route_evokers.where('? = ANY(character_id)', values.first).first
      @warnings << "New guidebook effect #{entry[:status_id]} names an unknown Evoker" unless character
      { target_type: 'character', target_values: values.uniq, character_id: character&.id }
    end

    def guidebook_entry(effect, entry, previous)
      count = entry[:num]
      if count > 1 && !effect.stackable?
        @warnings << "Guidebook effect #{effect.granblue_id} can't stack but the game shows #{count}; saved as 1"
        count = 1
      end

      {
        solomonis_guide_effect: effect,
        count: count,
        display_value: display_value(effect, entry),
        acquired_order: previous&.acquired_order,
        inherited: previous&.inherited || false,
        note: previous&.note
      }
    end

    # The run-dependent text in place of the catalogue's {value}.
    def display_value(effect, entry)
      template = normalize_text(entry[:japanese] ? effect.name_jp : effect.name_en)
      return nil unless template&.include?(VALUE_PLACEHOLDER)

      pattern = template.split(VALUE_PLACEHOLDER, -1).map { |part| Regexp.escape(part) }.join('(.+?)')
      match = entry[:text].match(/\A#{pattern}\z/)
      match && match[1].strip.truncate(ExpeditionGuideEffect::DISPLAY_VALUE_MAX_LENGTH, omission: '').presence
    end
  end
end
