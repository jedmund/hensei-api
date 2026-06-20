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

      # Odious series — from Odious/Verboten weapons
      ODIOUS_AURAS = [
        'Taboo Doomfire', 'Taboo Deluge', 'Taboo Galeforce',
        'Taboo Landslide', 'Taboo Flashpoint', 'Taboo Nightfall',
        'Taboo Allowater'
      ].freeze

      # Militis series — boosted by Militis summons
      MILITIS_AURAS = %w[
        Purgatory Snowfall Tranquility Ridge Glimmer Blaze
      ].freeze

      # Archangel series — from Archangel weapons
      ARCHANGEL_AURAS = %w[
        Gabriel Michael Raphael Uriel
      ].freeze

      # Ennead series — from Ennead (Exo) weapons
      ENNEAD_AURAS = [
        'Searing Enlightener', 'Elysian Windrider',
        'Baneful Hellbringer', 'Chthonian Bewailer'
      ].freeze

      # Arcana series — from Arcana weapons (Arcarum)
      ARCANA_AURAS = [
        'Hierophant-Sun', 'Fool-Hanged Man', 'Strength-Devil',
        'Chariot-Star', 'Empress-Justice', 'Emperor-Judgement',
        'High Priestess-Moon', 'Lovers-Death', 'Magician-Tower',
        'Hermit-Temperance'
      ].freeze

      # Ultima/Atma series — Latin element auras
      ULTIMA_AURAS = %w[
        Arsus Aquae Coeli Terrae Luminis Caliginis
      ].freeze

      # Bahamut series — color-based auras
      BAHAMUT_AURAS = [
        'Gale Green', 'Desert Yellow', 'Royal Purple',
        'Ocean Blue', 'Radiant Pearl'
      ].freeze

      # Class Champion Weapon auras — job-specific prefixes
      CCW_AURAS = %w[
        Contractor Dancer Revenger Rikishi Legend
        Conjurer Trovador Executioner Virtuoso
        Longstrider Kingpin Shredder Vigilante
        Hero Tetra Dragoon Legionnaire
        Barbarian Arcanist Noble Slaysnake
        Kengo Cavalier Gunslinger Oracle
        Venerator Nightbender Bulwark Paragon
        Wanderer Doctor Shadowhound Swordmaster
        Defender Sage
      ].freeze

      CCW_MULTI_WORD_AURAS = [
        'Holy Knight', 'King', 'War God',
        'Physician-Seer', 'Exorcist',
        'Enlightened Monk', 'Warrior Monk',
        'Dragon-Knight', 'Dual Blade',
        'Drum Master', 'Lone Wolf',
        'Empyrean Adjudicator', 'Adjudicator',
        'Sauna-Goer', 'Reigning Champ',
        'Resplendent Ruler', 'Rugged Woodcutter',
        'Kind Woodcutter', 'Forest Dweller',
        'Star-Sea Sovereign', 'Sovereign Defender',
        'Thunder God'
      ].freeze

      # Other unique auras that appear in weapon data
      OTHER_AURAS = %w[
        Mutiny Undersky Foxflame Sunveil
        Dreadflame Lightbeam Warspirit Dragonstrike
        Nue Spirit Debauchery Discipline
      ].freeze

      # Proficiency-based auras (weapon type skills)
      PROFICIENCY_AURAS = %w[
        Sword Blade Axe Dagger Staff Harp Bow Gauntlet
      ].freeze

      # Combined aura lookup: aura prefix → damage formula series.
      # Only the 4 real series are mapped here. All other aura prefixes
      # (Militis, CCW, Archangel, etc.) are weapon-specific skills that
      # don't belong to any damage formula series — they return nil.
      AURA_TO_SERIES = {}.tap do |h|
        NORMAL_AURAS.each { |a| h[a] = :normal }
        OMEGA_AURAS.each { |a| h[a] = :omega }
        EX_AURAS.each { |a| h[a] = :ex }
        ODIOUS_AURAS.each { |a| h[a] = :odious }
      end.freeze

      # All known aura prefixes (for permissive matching).
      # If a possessive skill name uses a known aura, we accept the modifier
      # even if it's not in KNOWN_MODIFIERS (weapon-specific unique skills).
      ALL_KNOWN_AURAS = Set.new(
        NORMAL_AURAS + OMEGA_AURAS + EX_AURAS + ODIOUS_AURAS +
        MILITIS_AURAS + ARCHANGEL_AURAS + ENNEAD_AURAS + ARCANA_AURAS +
        ULTIMA_AURAS + BAHAMUT_AURAS + CCW_AURAS + CCW_MULTI_WORD_AURAS +
        OTHER_AURAS + PROFICIENCY_AURAS
      ).freeze

      # Skill modifiers that are boostable by aura (standard damage formula)
      BOOSTABLE_MODIFIERS = %w[
        Abandon Aegis Apotheosis Auspice Betrayal Bladeshield Bloodshed
        Celere Clarity Deathstrike Demolishment Devastation Dual-Edge
        Empowerment Encouragement Enmity Essence Fandango Garrison Glory Grace
        Haunt Healing Heed Heroism Impalement Insignia Majesty Might
        Mystery Onslaught Precocity Primacy Progression Resolve Restraint Sapience
        Sentence Spearhead Stamina Stratagem Sweep Tempering Trituration
        Trium Truce Tyranny Verity Verve
      ].freeze

      # Skill modifiers with flat values
      FLAT_MODIFIERS = %w[
        Aramis Ars Arts Ascendancy Athos Blessing Bloodrage Blow Charge
        Convergence Craft Dominion Enforcement Excelsior Exertion Fathoms
        Fortified Fortitude Frailty Godblade Godflair Godheart Godshield
        Godstrike Honing Initiation Marvel Pact Parity Persistence Plenum
        Porthos Quenching Quintessence Resonator Rigor Rubell Ruination
        Sovereign Spectacle Strike Supremacy Surge
        Ultio Utopia Valuables Vitality Vivification Voltage Wrath
      ].freeze

      # Multi-word flat modifiers
      FLAT_MULTI_WORD_MODIFIERS = [
        'Beast Essence', 'Chain Force',
        'Draconic Barrier', 'Draconic Fortitude', 'Draconic Magnitude',
        'Draconic Progression',
        'Fulgor Elatio', 'Fulgor Fortis', 'Fulgor Impetus', 'Fulgor Sanatio',
        'Grand Epic',
        'Omega Exalto', 'Optimus Exalto',
        'Preemptive Barrier', 'Preemptive Blade', 'Preemptive Wall',
        'Scandere Aggressio', 'Scandere Arcanum', 'Scandere Catena',
        'Scandere Facultas',
        'Sephira Legio', 'Sephira Manus', 'Sephira Maxi',
        'Sephira Salire', 'Sephira Soul', 'Sephira Tek', 'Sephira Telum',
        'Striking Art', 'Supremacy: Decimation',
        'True Dragon Barrier', 'True Supremacy',
        'Zenith Art', 'Zenith Strike',
        'α Revelation', 'β Revelation', 'γ Revelation', 'Δ Revelation'
      ].freeze

      # Modifiers that can be boostable or flat depending on context
      DEPENDENT_MODIFIERS = %w[
        Crux
      ].freeze

      # CCW/Ennead/Arcana/unique modifiers (don't follow standard damage formula)
      SPECIAL_MODIFIERS = %w[
        Acumen Accord Apex Armed Awakening Bewitching Calling Calamity
        Clawed Demise Discipline Erudition Gauntlet Genius Honor Hunt
        Jurisdiction Maneuver Myth Nature Perseverance
        Pride Prowess Refuge Resilient Roar Sanctity Seduction Strength
        Swing Truth Virtue Willed
      ].freeze

      # Multi-word special modifiers
      SPECIAL_MULTI_WORD_MODIFIERS = [
        'Covert Artistry',
        'First Dash', 'Fortified Blade', 'Fortified Harp', 'Fortified Staff',
        'Fourth Pursuit',
        'Frost Blade', 'Light Blade',
        'Mysterious ATK', 'Mysterious VIT',
        'Saw of Death', 'Second Insignia', 'Shadow Blade',
        'Staff Resonance',
        'Strike: Dark', 'Strike: Earth', 'Strike: Fire',
        'Strike: Light', 'Strike: Water', 'Strike: Wind',
        'Synchronized Artistry',
        'Technical Artistry',
        'Terra Blade', 'Third Spur'
      ].freeze

      KNOWN_MODIFIERS = (
        BOOSTABLE_MODIFIERS + FLAT_MODIFIERS + FLAT_MULTI_WORD_MODIFIERS +
        DEPENDENT_MODIFIERS + SPECIAL_MODIFIERS + SPECIAL_MULTI_WORD_MODIFIERS
      ).freeze

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

      # Maps {{WeaponSkillMod|...}} template params to series
      TEMPLATE_SERIES_MAP = {
        'normal' => 'normal',
        'color' => 'ex',
        'unique' => nil
      }.freeze

      TEMPLATE_SIZE_MAP = {
        'big' => 'big',
        'medium' => 'medium',
        'small' => 'small'
      }.freeze

      # Sephira element-specific skill name patterns.
      # Maps element-specific names to their generic modifier.
      # e.g. "Sephira Fire-Tek" → "Sephira Tek", "Sephira Firesoul" → "Sephira Soul"
      SEPHIRA_ELEMENT_PATTERN = /\ASephira\s+(.+)\z/
      SEPHIRA_TEK_PATTERN = /\A(?:Fire|Water|Earth|Wind|Light|Dark)-Tek\z/
      SEPHIRA_SOUL_PATTERN = /\A(?:Fire|Water|Earth|Wind)soul\z/
      SEPHIRA_SUB_PATTERN = /\A(Legio|Manus|Salire|Telum)\s+/

      # Element-specific normalization constants.
      # English element words used in Clawed/Armed skill names.
      ELEMENT_WORDS = Set.new(%w[Shadow Blaze Grounds Gale Flood Shine]).freeze

      # Latin element words used in Exalto-family skill names.
      LATIN_ELEMENT_WORDS = Set.new(%w[Caliginis Aeros Luminis Aquae Terrae Ardendi]).freeze

      # Element words used in Preemptive element-specific patterns.
      PREEMPTIVE_ELEMENT_WORDS = Set.new(%w[Fire Rock Shadow Ice Gale Silver Azure Amber Cloud]).freeze

      # Modifiers that appear with element word suffixes (e.g. "Clawed Shadow" → "Clawed").
      ELEMENT_SUFFIXED_MODIFIERS = Set.new(%w[Armed Clawed Resilient Willed]).freeze

      # Parses a weapon skill name into structured components.
      #
      # @param skill_name [String] e.g. "Inferno's Might II", "{{WeaponSkillMod|big normal}} Enmity"
      # @return [Hash] { aura:, modifier:, series:, size:, skill_name: }
      def self.parse(skill_name)
        return empty_result(skill_name) if skill_name.blank?

        # Strip HTML comments from wiki data
        clean_name = skill_name.gsub(/<!--.*?-->/, '').strip

        # Handle {{WeaponSkillMod|...}} template syntax
        if clean_name.include?('{{WeaponSkillMod|')
          return parse_template_skill(clean_name, skill_name)
        end

        # Extract trailing roman numeral
        numeral = nil
        base_name = clean_name
        if clean_name =~ NUMERAL_PATTERN
          numeral = Regexp.last_match(0).strip
          base_name = clean_name.sub(NUMERAL_PATTERN, '')
        end

        # Try possessive format: "Aura's Modifier" or "Multi Word Aura's Modifier"
        if (match = base_name.match(/^(.+?)'s\s+(.+)$/))
          aura = match[1]
          modifier = match[2]

          # Accept if modifier is known, OR if aura is a known prefix
          # (weapon-specific skills use known auras with unique modifiers)
          if KNOWN_MODIFIERS.include?(modifier) || ALL_KNOWN_AURAS.include?(aura)
            return {
              aura: aura,
              modifier: modifier,
              series: AURA_TO_SERIES[aura]&.to_s,
              size: NUMERAL_TO_SIZE[numeral],
              skill_name: skill_name
            }
          end
        end

        # Try non-possessive format: check if the last word(s) match a known modifier
        words = base_name.split
        if words.size >= 2
          # Try last 2+ words as multi-word modifier
          (FLAT_MULTI_WORD_MODIFIERS + SPECIAL_MULTI_WORD_MODIFIERS).each do |multi_mod|
            next unless base_name.end_with?(multi_mod) && base_name.length > multi_mod.length + 1

            aura = base_name[0..-(multi_mod.length + 2)]
            return {
              aura: aura,
              modifier: multi_mod,
              series: AURA_TO_SERIES[aura]&.to_s,
              size: NUMERAL_TO_SIZE[numeral],
              skill_name: skill_name
            }
          end

          # Try last word as single-word modifier
          modifier = words.last
          if KNOWN_MODIFIERS.include?(modifier) && !FLAT_MULTI_WORD_MODIFIERS.include?(modifier)
            aura = words[0..-2].join(' ')
            return {
              aura: aura,
              modifier: modifier,
              series: AURA_TO_SERIES[aura]&.to_s,
              size: NUMERAL_TO_SIZE[numeral],
              skill_name: skill_name
            }
          end
        end

        # Try standalone modifier (no aura prefix) — e.g. "Godblade I", "Scandere Aggressio"
        if KNOWN_MODIFIERS.include?(base_name)
          return {
            aura: nil,
            modifier: base_name,
            series: nil,
            size: NUMERAL_TO_SIZE[numeral],
            skill_name: skill_name
          }
        end

        # Try Sephira element-specific names
        # e.g. "Sephira Fire-Tek" → "Sephira Tek", "Sephira Legio Ventus" → "Sephira Legio"
        if (sephira_match = base_name.match(SEPHIRA_ELEMENT_PATTERN))
          suffix = sephira_match[1]
          sephira_modifier = resolve_sephira_modifier(suffix)
          if sephira_modifier
            return {
              aura: nil,
              modifier: sephira_modifier,
              series: nil,
              size: NUMERAL_TO_SIZE[numeral],
              skill_name: skill_name
            }
          end
        end

        # Try element-specific normalization
        # e.g. "Clawed Shadow" → "Clawed", "Preemptive Fire Blade" → "Preemptive Blade"
        normalized = normalize_element_specific(base_name)
        if normalized && KNOWN_MODIFIERS.include?(normalized[:modifier])
          return {
            aura: nil,
            modifier: normalized[:modifier],
            series: normalized[:series],
            size: NUMERAL_TO_SIZE[numeral],
            skill_name: skill_name
          }
        end

        # Unrecognized skill
        { aura: nil, modifier: nil, series: nil, size: nil, skill_name: skill_name }
      end

      # Parses {{WeaponSkillMod|params}} ModifierName format.
      # Template params encode series and size: "big normal", "medium normal", "color", "unique"
      def self.parse_template_skill(clean_name, original_name)
        if (match = clean_name.match(/\{\{WeaponSkillMod\|([^}]+)\}\}\s*(.+)/))
          params = match[1].strip
          modifier = match[2].strip

          # Parse template params for series and size
          parts = params.split
          size = nil
          series = nil

          parts.each do |part|
            if TEMPLATE_SIZE_MAP.key?(part)
              size = TEMPLATE_SIZE_MAP[part]
            elsif TEMPLATE_SERIES_MAP.key?(part)
              series = TEMPLATE_SERIES_MAP[part]
            end
          end

          return {
            aura: nil,
            modifier: modifier,
            series: series,
            size: size,
            skill_name: original_name
          }
        end

        empty_result(original_name)
      end

      # Maps Sephira element-specific suffixes to generic modifier names.
      # e.g. "Fire-Tek" → "Sephira Tek", "Firesoul" → "Sephira Soul"
      def self.resolve_sephira_modifier(suffix)
        if suffix.match?(SEPHIRA_TEK_PATTERN)
          'Sephira Tek'
        elsif suffix.match?(SEPHIRA_SOUL_PATTERN)
          'Sephira Soul'
        elsif suffix.match?(SEPHIRA_SUB_PATTERN)
          "Sephira #{suffix.match(SEPHIRA_SUB_PATTERN)[1]}"
        end
      end

      # Normalizes element-specific skill names to their generic modifier form.
      # Returns a hash with :modifier and optionally :series, or nil if no pattern matched.
      def self.normalize_element_specific(base_name)
        words = base_name.split

        # "{Omega|Optimus} Exalto {latin_element}" → Exalto with series
        if words.size == 3 && words[1] == 'Exalto' && LATIN_ELEMENT_WORDS.include?(words[2])
          if words[0] == 'Omega'
            return { modifier: 'Omega Exalto', series: 'omega' }
          elsif words[0] == 'Optimus'
            return { modifier: 'Optimus Exalto', series: 'normal' }
          end
        end

        # "Preemptive {element} {base}" → "Preemptive {base}"
        if words.size == 3 && words[0] == 'Preemptive' && PREEMPTIVE_ELEMENT_WORDS.include?(words[1])
          return { modifier: "Preemptive #{words[2]}" }
        end

        # "{Clawed|Armed} {element_word}" → "{Clawed|Armed}"
        if words.size == 2 && ELEMENT_WORDS.include?(words[1]) && ELEMENT_SUFFIXED_MODIFIERS.include?(words[0])
          return { modifier: words[0] }
        end

        nil
      end

      def self.empty_result(skill_name)
        { aura: nil, modifier: nil, series: nil, size: nil, skill_name: skill_name }
      end

      private_class_method :empty_result, :parse_template_skill, :resolve_sephira_modifier,
                           :normalize_element_specific
    end
  end
end
