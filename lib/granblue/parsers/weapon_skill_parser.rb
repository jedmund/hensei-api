# frozen_string_literal: true

module Granblue
  module Parsers
    class WeaponSkillParser
      # Aura prefixes grouped by skill series.
      # The aura prefix determines which summon auras boost the skill.

      # Normal series — boosted by Optimus summons (Agni, Varuna, Titan, Zephyrus, Zeus, Hades)
      NORMAL_AURAS = %w[
        Fire Hellfire Inferno
        Water Tsunami Hoarfrost
        Wind Whirlwind Ventosus
        Earth Mountain Terra
        Light Thunder Zion
        Dark Hatred Oblivion
      ].freeze

      # Omega series — boosted by Omega summons (Colossus, Leviathan, Yggdrasil, Tiamat, Luminiera, Celeste)
      OMEGA_AURAS = %w[
        Ironflame Oceansoul Stormwyrm Lifetree Knightcode Mistfall
      ].freeze

      # EX series — not boosted by any summon aura
      EX_AURAS = %w[
        Scarlet Cobalt Jade Amber Golden Graphite
      ].freeze

      # Odious series — from Odious weapons
      ODIOUS_AURAS = [
        'Taboo Doomfire',
        'Taboo Deluge',
        'Taboo Galeforce',
        'Taboo Landslide',
        'Taboo Flashpoint',
        'Taboo Nightfall'
      ].freeze

      # Combined aura lookup: aura prefix → skill series
      AURA_TO_SERIES = {}.tap do |h|
        NORMAL_AURAS.each { |a| h[a] = :normal }
        OMEGA_AURAS.each { |a| h[a] = :omega }
        EX_AURAS.each { |a| h[a] = :ex }
        ODIOUS_AURAS.each { |a| h[a] = :odious }
      end.freeze

      # All known aura prefixes
      KNOWN_AURAS = AURA_TO_SERIES.keys.freeze

      # Skill modifiers that are boostable by aura
      BOOSTABLE_MODIFIERS = %w[
        Abandon Aegis Apotheosis Auspice Betrayal Bladeshield Bloodshed
        Celere Clarity Deathstrike Demolishment Devastation Dual-Edge
        Empowerment Encouragement Enmity Essence Fandango Garrison Glory Grace
        Haunt Healing Heed Heroism Impalement Insignia Majesty Might
        Mystery Precocity Primacy Progression Resolve Restraint Sapience
        Sentence Spearhead Stamina Stratagem Sweep Tempering Trituration
        Trium Truce Tyranny Verity Verve
      ].freeze

      # Skill modifiers with flat values, not boostable by aura
      FLAT_MODIFIERS = %w[
        Arts Ascendancy Blessing Blow Charge Convergence Craft
        Enforcement Excelsior Exertion Fortified Fortitude Frailty
        Initiation Marvel Pact Persistence Quenching Quintessence
        Resonator Sovereign Spectacle Strike Supremacy Surge Swashbuckler
        Valuables Vitality Vivification Voltage Wrath
      ].freeze

      # Multi-word flat modifiers
      FLAT_MULTI_WORD_MODIFIERS = [
        'Beast Essence', 'Chain Force', 'Grand Epic',
        'Omega Exalto', 'Optimus Exalto',
        'Preemptive Barrier', 'Preemptive Blade', 'Preemptive Wall',
        'Sephira Maxi', 'Sephira Soul', 'Sephira Tek',
        'Striking Art', 'True Supremacy',
        'Zenith Art', 'Zenith Strike'
      ].freeze

      # Modifiers that can be boostable or flat depending on context
      DEPENDENT_MODIFIERS = %w[
        Crux
      ].freeze

      KNOWN_MODIFIERS = (BOOSTABLE_MODIFIERS + FLAT_MODIFIERS + FLAT_MULTI_WORD_MODIFIERS + DEPENDENT_MODIFIERS).freeze

      # Roman numeral pattern for skill size tiers
      NUMERAL_PATTERN = /\s+(I{1,3}V?|IV|V)$/

      # Maps roman numerals to skill size
      NUMERAL_TO_SIZE = {
        nil => nil,
        'I' => 'small',
        'II' => 'medium',
        'III' => 'big',
        'IV' => 'massive',
        'V' => 'massive'
      }.freeze

      # Parses a weapon skill name into structured components.
      #
      # @param skill_name [String] e.g. "Inferno's Might II", "Taboo Doomfire's Majesty IV"
      # @return [Hash] { aura:, modifier:, series:, size:, skill_name: }
      def self.parse(skill_name)
        return empty_result(skill_name) if skill_name.blank?

        # Extract trailing roman numeral
        numeral = nil
        base_name = skill_name
        if skill_name =~ NUMERAL_PATTERN
          numeral = Regexp.last_match(0).strip
          base_name = skill_name.sub(NUMERAL_PATTERN, '')
        end

        # Try possessive format: "Aura's Modifier" or "Multi Word Aura's Modifier"
        if (match = base_name.match(/^(.+?)'s\s+(.+)$/))
          aura = match[1]
          modifier = match[2]

          if AURA_TO_SERIES.key?(aura) && KNOWN_MODIFIERS.include?(modifier)
            return {
              aura: aura,
              modifier: modifier,
              series: AURA_TO_SERIES[aura].to_s,
              size: NUMERAL_TO_SIZE[numeral],
              skill_name: skill_name
            }
          end
        end

        # Try two-word format without possessive: "Aura Modifier"
        if base_name.split.size == 2
          parts = base_name.split
          aura = parts[0]
          modifier = parts[1]

          if AURA_TO_SERIES.key?(aura) && KNOWN_MODIFIERS.include?(modifier)
            return {
              aura: aura,
              modifier: modifier,
              series: AURA_TO_SERIES[aura].to_s,
              size: NUMERAL_TO_SIZE[numeral],
              skill_name: skill_name
            }
          end
        end

        # Unrecognized skill
        { aura: nil, modifier: nil, series: nil, size: nil, skill_name: skill_name }
      end

      def self.empty_result(skill_name)
        { aura: nil, modifier: nil, series: nil, size: nil, skill_name: skill_name }
      end

      private_class_method :empty_result
    end
  end
end
