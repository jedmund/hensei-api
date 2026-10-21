# frozen_string_literal: true

module Granblue
  # Reading a character detail payload (/archive/npc_detail) the way the game sends it (D39).
  #
  # - Language: the game answers in the account's language, so a payload's language is
  #   judged from its skill names (Japanese text → jp), not from what the caller says.
  # - Character: the top-level id can be the player's own npc instance id; master.id is the
  #   character's granblue_id. The style is `style`, or `param.style`.
  module GamePayload
    JAPANESE = /[\p{Hiragana}\p{Katakana}\p{Han}]/
    SKILL_KEYS = %w[ability special_skill power_up_special_skill support_ability backmember_ability appear_ability].freeze

    module_function

    # → "jp", "en", or nil when the payload has no skill names to judge.
    def language(payload)
      names = skill_names(payload)
      return if names.empty?

      names.any? { |name| name.match?(JAPANESE) } ? 'jp' : 'en'
    end

    def granblue_id(payload)
      (payload.dig('master', 'id').presence || payload['id']).presence&.to_s
    end

    # → "1", "2", … or "" when the payload doesn't say.
    def style(payload)
      (payload['style'].presence || payload.dig('param', 'style')).to_s
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
