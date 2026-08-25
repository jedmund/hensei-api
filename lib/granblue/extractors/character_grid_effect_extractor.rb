# frozen_string_literal: true

require Rails.root.join("lib/granblue/parsers/weapon_skill_parser")

module Granblue
  module Extractors
    # Extracts grid-affecting effects from a character SUPPORT skill description into
    # structured SkillEffect attributes. Currently handles the aura-booster pattern
    # ("X% boost to <aura-words>'s weapon skills/skill effects", e.g. the Arche and
    # Emissary passives):
    # each aura-word maps to a (frame, element) via the same WeaponSkillParser tables the
    # weapon/summon pipelines use, so the meaning is modeled, not stored as plaintext.
    class CharacterGridEffectExtractor
      P = Granblue::Parsers::WeaponSkillParser
      ELEMENTS = %w[fire water wind earth light dark].freeze
      CHARACTER_ELEMENT_BY_ID = {
        1 => "wind", 2 => "fire", 3 => "water", 4 => "earth", 5 => "dark", 6 => "light"
      }.freeze

      # aura-word (downcased) => [frame, element]
      WORD_MAP = {}.tap do |m|
        P::NORMAL_AURAS.each_with_index { |w, i| m[w.downcase] = ["normal", ELEMENTS[i / 3]] }
        P::OMEGA_AURAS.each_with_index { |w, i| m[w.downcase] = ["omega", ELEMENTS[i]] }
      end.freeze

      # description (String) -> Array<Hash> of SkillEffect attrs (effect_type/frame/element/amount).
      # When element is supplied, aura words for another element are rejected. This keeps
      # stale/misassigned wiki data from giving a character an off-element grid passive.
      def extract(description, element: nil)
        return [] if description.blank?

        m = description.match(/(\d+(?:\.\d+)?)%\s*boost to\s+(.+?)\s+(?:weapon skills|skill effects)/i)
        return [] unless m

        value = m[1].to_f
        words_part = m[2].downcase
        pairs = WORD_MAP.select { |w, _| words_part.match?(/\b#{Regexp.escape(w)}\b/) }.values.uniq
        pairs.select! { |_, effect_element| effect_element == element.to_s } if element.present?
        pairs.map do |frame, effect_element|
          { effect_type: "weapon_skill_boost", frame: frame, element: effect_element,
            amount: value, target: "element_allies" }
        end
      end
    end
  end
end
