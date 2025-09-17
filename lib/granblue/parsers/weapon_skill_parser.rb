# frozen_string_literal: true

module Granblue
  module Parsers
    class WeaponSkillParser
      OPTIMUS_AURAS = %w[
        Fire Hellfire Inferno
        Water Tsunami Hoarfrost
        Wind Whirlwind Ventosus
        Earth Mountain Terra
        Light THunder Zion
        Dark Hatred Oblivion
      ].freeze

      OMEGA_AURAS = %w[
        Ironflame Oceansoul Stormwyrm Lifetree Knightcode Mistfall
      ]

      UNBOOSTABLE_AURAS = %w[
        Scarlet Cobalt Jade Amber Golden Graphite
      ].freeze

      # These skills are boostable by aura
      BOOSTABLE_SKILLS = %w[
        Abandon Aegis Apotheosis Auspice Betrayal Bladeshield Bloodshed
        Celere Clarity Deathstrike Demolishment Devastation Dual-Edge
        Encouragement Enmity Essence Fandango Garrison Glory Grace
        Haunt Healing Heed Heroism Impalement Insignia Majesty Might
        Mystery Precocity Primacy Progression Resolve Restraint Sapience
        Sentence Spearhead Stamina Stratagem Sweep Tempering Trituration
        Trium Truce Tyranny Verity Verve
      ].freeze

      # These skills have flat values and are not boostable by aura
      UNBOOSTABLE_SKILLS = %w[
        Arts Ascendancy "Beast Essence" Blessing Blow "Chain Force"
        Charge Convergence Craft Enforcement Excelsior Exertion Fortified
        Fortitude Frailty "Grand Epic" Initiation Marvel "Omega Exalto"
        "Optimus Exalto" Pact Persistence "Preemptive Barrier"
        "Preemptive Blade" "Preemptive Wall" Quenching Quintessence
        Resonator "Sephira Maxi" "Sephira Soul" "Sephira Tek" Sovereign
        Spectacle Strike "Striking Art" Supremacy Surge Swashbuckler
        "True Supremacy" Valuables Vitality Vivification Voltage
        Wrath "Zenith Art" "Zenith Strike"
      ]

      # These skills can be boostable or unboostable depending on the source
      DEPENDENT_SKILLS = %w[
        Crux
      ].freeze

      def self.parse(skill_name)
        return { aura: nil, skill_type: nil, skill_name: skill_name } if skill_name.blank?

        # Handle standard format: "Aura's Skill [I-IV]"
        if match = skill_name.match(/^(.*?)'s\s+(.+?)(?:\s+(I{1,3}V?|IV))?$/)
          aura = match[1]
          skill = match[2]
          numeral = match[3]

          skill_with_numeral = numeral ? "#{skill} #{numeral}" : skill

          # Check if aura and skill are in known lists
          if KNOWN_AURAS.include?(aura) && KNOWN_SKILLS.include?(skill)
            return { aura: aura, skill_type: skill, skill_name: skill_name }
          end

          return { aura: nil, skill_type: 'Special', skill_name: skill_name }

        end

        # Handle two-word format without possessive: "Aura Skill"
        if skill_name.split.size == 2
          parts = skill_name.split
          aura = parts[0]
          skill = parts[1]

          # Check if aura and skill are in known lists
          if KNOWN_AURAS.include?(aura) && KNOWN_SKILLS.include?(skill)
            return { aura: aura, skill_type: skill, skill_name: skill_name }
          end

          return { aura: nil, skill_type: 'Special', skill_name: skill_name }

        end

        # Fallback for special cases
        { aura: nil, skill_type: 'Special', skill_name: skill_name }
      end

      # Method to extend dictionaries
      def self.add_aura(aura)
        KNOWN_AURAS << aura unless KNOWN_AURAS.include?(aura)
      end

      def self.add_skill(skill)
        KNOWN_SKILLS << skill unless KNOWN_SKILLS.include?(skill)
      end
    end
  end
end
