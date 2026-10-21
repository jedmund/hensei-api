# frozen_string_literal: true

module Granblue
  # Reading a character detail payload (/archive/npc_detail) the way the game sends it (D39).
  #
  # - Language: the game answers in the account's language, so a payload's language is
  #   judged from its skill names (most of them Japanese → jp, most not → en).
  # - Character: the top-level id can be the player's own npc instance id; master.id is the
  #   character's granblue_id. The style is `style`, or `param.style`.
  # - Storing: .sanitize keeps the character's own data only (an allowlist).
  module GamePayload
    JAPANESE = /[\p{Hiragana}\p{Katakana}\p{Han}]/
    SKILL_KEYS = %w[ability special_skill power_up_special_skill support_ability backmember_ability appear_ability].freeze
    # Top-level keys kept by .sanitize: the character's skills and catalogue data, and what
    # CharacterWikiData, Dataminer and the import read. Everything else (the player's own
    # instance, rank, story and voice progress, …) is dropped.
    KEEP_KEYS = (SKILL_KEYS + %w[
      master style style_list name evo_name comment type weapon rarity rarity_name attribute tribe tribe_2
      series_id specialty_weapon max_level default_attack default_hp max_attack max_hp kind_name
      is_numbers is_arcarum_npc max_awakening_level is_show_skill_change
    ]).freeze
    # param keys kept (the rest are the player's stats for their copy).
    KEEP_PARAM_KEYS = %w[style rarity image_id_9].freeze

    module_function

    # → "jp" when most skill names have Japanese text, "en" when most don't, nil when there
    # are none or it's a tie (the caller's lang decides those).
    def language(payload)
      japanese, other = skill_names(payload).partition { |name| name.match?(JAPANESE) }
      return 'jp' if japanese.size > other.size
      return 'en' if other.size > japanese.size

      nil
    end

    # The payload with only character data (KEEP_KEYS, param's KEEP_PARAM_KEYS). The
    # top-level id stays only when it is the character's (no master block). A non-Hash is
    # returned as is.
    def sanitize(payload)
      return payload unless payload.is_a?(Hash)

      kept = payload.slice(*KEEP_KEYS)
      kept['id'] = payload['id'] if payload.key?('id') && !payload['master'].is_a?(Hash)
      kept['param'] = payload['param'].slice(*KEEP_PARAM_KEYS) if payload['param'].is_a?(Hash)
      kept
    end

    # → the granblue_id, or nil (a malformed body included).
    def granblue_id(payload)
      return unless payload.is_a?(Hash)

      id = section(payload, 'master')['id'].presence || payload['id'].presence
      id.to_s if id.is_a?(String) || id.is_a?(Integer)
    end

    # → "1", "2", … or "" when the payload doesn't say.
    def style(payload)
      return '' unless payload.is_a?(Hash)

      style = payload['style'].presence || section(payload, 'param')['style']
      style.is_a?(String) || style.is_a?(Integer) ? style.to_s : ''
    end

    # The series id from the payload (master.series_id is a list), or nil.
    def series_id(payload)
      return unless payload.is_a?(Hash)

      value = payload['series_id'] || section(payload, 'master')['series_id']
      value = value.first if value.is_a?(Array)
      value.to_s if value.is_a?(String) || value.is_a?(Integer)
    end

    def section(payload, key)
      payload[key].is_a?(Hash) ? payload[key] : {}
    end

    def skill_names(payload)
      return [] unless payload.is_a?(Hash)

      SKILL_KEYS.flat_map { |key| actions(payload[key]) }.filter_map { |action| action['name'].presence&.to_s }
    end

    # A skill key holds one action ({ name: … }) or a list/hash of them.
    def actions(value)
      case value
      when Hash then value.key?('name') ? [value] : value.values.grep(Hash)
      when Array then value.grep(Hash)
      else []
      end
    end
  end
end
