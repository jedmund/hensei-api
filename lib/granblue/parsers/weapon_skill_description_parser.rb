# frozen_string_literal: true

module Granblue
  module Parsers
    # Parses a weapon-skill DESCRIPTION (the wiki `sN_desc` / `ensN_desc` prose) into
    # structured boost clauses. The description is the single source of truth for a skill's
    # grid effect — NEVER the icon. Output drives the weapon_skill_data / weapon_skill_effects
    # extraction.
    #
    #   WeaponSkillDescriptionParser.parse(
    #     "When main weapon: Supplement Water allies' damage by 100,000, 10% boost to damage cap")
    #   => { main_hand_only: true, mc_only: false, skip: nil,
    #        clauses: [ {boost_type:"dmg_supp", value:100000.0, size:nil, series:"normal", ...},
    #                   {boost_type:"dmg_cap",  value:10.0,    size:nil, series:"normal", ...} ] }
    class WeaponSkillDescriptionParser
      SIZE_KEYWORD = /\b(unworldly|massive|big|medium|small)\b/i

      # Descriptions we deliberately do NOT model as passive grid boosts (logged, not lost):
      #   - key placeholders (resolved by the key→skill resolver)
      #   - dynamic buff-on-action (stackable status gained on an action/hit)
      #   - pure nukes / charge-bar-only / cooldown effects with no passive grid contribution
      SKIP_PATTERNS = {
        "key_placeholder" => /empowered by a chosen (teluma|pendulum|chain)|a gate to the summits|locked within ultima|granted power with an anklet/i,
        "dynamic_buff"    => /gain \{\{status|allies gain .*\bupon\b|\bstack(able|ing)\b.*upon/i,
        "nuke_only"       => /\bdeal[s]? .*% .*(dmg|damage) to (all|random|a) foe|plain damage/i
      }.freeze

      # Ordered (specific → general) phrase → boost_type (or array for "specs" bundles).
      # Within a clause we match-and-consume so a specific phrase ("skill DMG cap") prevents
      # the general one ("DMG cap") re-matching.
      BOOST_PATTERNS = [
        [/(?:charge attack|c\.?a\.?) specs/i,               %w[ca_dmg ca_dmg_cap]],
        [/chain ?burst specs/i,                             %w[cb_dmg cb_dmg_cap]],
        [/skill (?:dmg|damage) cap/i,                        "skill_dmg_cap"],
        [/(?:normal attack|n\.?a\.?) (?:dmg|damage) cap/i,   "na_dmg_cap"],
        [/(?:charge attack|c\.?a\.?) (?:dmg|damage) cap/i,   "ca_dmg_cap"],
        [/chain ?burst (?:dmg|damage) cap/i,                 "cb_dmg_cap"],
        [/healing cap|boost to healing/i,                    "heal_cap"],
        [/(?:dmg|damage) cap/i,                              "dmg_cap"],
        [/amplif\w*.*(?:normal attack|n\.?a\.?)|(?:normal attack|n\.?a\.?).*amplif/i, "na_amp"],
        [/amplif\w*.*(?:charge attack|c\.?a\.?)|(?:charge attack|c\.?a\.?).*amplif/i, "ca_amp_sp"],
        [/amplif\w*.*skill|skill.*amplif/i,                  "skill_amp_sp"],
        [/amplif\w*.*elemental|elemental .*amplif|amplify elemental|amplif\w*.*against .*foes/i, "elem_amplify"],
        [/amplif/i,                                          "dmg_amp"],
        [/supplement.*(?:charge attack|c\.?a\.?)/i,          "ca_supp"],
        [/supplement.*skill/i,                               "skill_dmg_supp"],
        [/supplement.*(?:normal attack|n\.?a\.?)/i,          "na_supp"],
        [/supplement/i,                                      "dmg_supp"],
        # Destruction (Destroyer weapons) is a damage TYPE, not an element — keep it off the
        # elemental "Bonus Water DMG" line. Must precede the generic bonus patterns.
        [/(?:bonus )?destruction.*?(?:charge attack|c\.?a\.?).*?(?:dmg|damage)/i, "bonus_des_ca"],
        [/(?:bonus )?destruction.*?(?:dmg|damage)/i,         "bonus_des_dmg"],
        [/bonus.*(?:charge attack|c\.?a\.?)/i,               "bonus_ca"],
        # Single-attack-only bonus DMG (Hraesvelgr's Einar) is its own mechanic — it does NOT
        # appear on the panel's elemental "Bonus DMG" line (5JPIJg: panel shows only the
        # always-on Deathstrike bonus). Must precede the generic elemental bonus pattern.
        [/bonus.*(?:dmg|damage).*single attacks?|single attacks?.*bonus.*(?:dmg|damage)/i, "bonus_elem_dmg_single"],
        [/bonus.*(?:dmg|damage)/i,                           "bonus_elem_dmg"],
        [/hit to (?:multiattack|double attack|triple attack)/i, "multiattack"], # → −DA (guarantee)
        [/multiattack rate/i,                               %w[da ta]],        # +DA and +TA
        [/double attack rate|\bda rate\b/i,                  "da"],
        [/triple attack rate|\bta rate\b/i,                  "ta"],
        [/critical/i,                                        "critical"],
        [/counter/i,                                         "counter_dmg"],
        [/gain shield|\bshield\b/i,                          "shield"],
        [/debuff res/i,                                      "debuff_res"],
        [/boost to charge bar gain|charge bar gain (?:boost|up)/i, "charge_gain"],
        [/(?:dmg|damage) (?:cut|reduc)|lessen .*(?:dmg|damage)/i, "elem_reduc"],
        [/chain ?burst (?:dmg|damage)/i,                     "cb_dmg"],
        [/(?:charge attack|c\.?a\.?) (?:dmg|damage)/i,       "ca_dmg"],
        [/ignore .*\bdef/i,                                  "def_ignore"],
        [/cut to .*max hp|% cut to/i,                        "hp_cut"],
        [/take (?:dmg|damage) worth|(?:dmg|damage) worth \d+% of max hp/i, "hp_dmg"],
        [/\bdef(?:ense)?\b/i,                                "def"],
        [/max hp|\bhp\b/i,                                   "hp"],
        [/\batk\b/i,                                         "atk"]
      ].freeze

      AURA_TO_SERIES = WeaponSkillParser::AURA_TO_SERIES

      def self.parse(description, name: nil)
        desc = clean(description)
        return blank_result if desc.blank?

        if name =~ /\b(Optimus|Omega) Exalto\b/i # frame-amplifier ("boost to …'s weapon skills")
          ex = "#{Regexp.last_match(1).downcase}_exalto"
          return blank_result.merge(clauses: [{ boost_type: ex, value: value_for(desc, ex), size: nil,
                                                series: (ex == "omega_exalto" ? "omega" : "normal"),
                                                formula_type: "flat", condition: nil }])
        end

        body = desc.sub(/\Awhen main weapon[^:]*:/i, "").sub(/\A[^:]*\(mc only\)[^:]*:/i, "")
        series0 = series_for(desc, name)

        clauses = []
        last_size = nil
        split_clauses(body).each do |frag|
          size = frag[SIZE_KEYWORD, 1]&.downcase || last_size
          last_size = size if frag.match?(SIZE_KEYWORD)
          boosts_for(frag).each do |boost, formula|
            boost = "od_dmg_amp" if boost == "dmg_amp" && series0 == "odious"
            value = value_for(frag, boost)
            # "X% hit to multiattack rate" guarantees multiattack ≈ −X% DA (it pushes the DA
            # rate down/negative; the freed rate becomes triple attacks).
            if boost == "multiattack"
              boost = "da"
              value = -value if value
            end
            clauses << {
              boost_type: boost, value: value, size: (size unless explicit?(frag)),
              series: series0, formula_type: formula, condition: condition_for(frag)
            }
          end
        end

        # Non-grid fragments (nukes, charge-bar, etc.) simply match no boost pattern and drop
        # out. `skip` is reported only when a skill yields no grid clause at all — for logging,
        # not loss.
        { main_hand_only: desc.match?(/when main weapon/i),
          mc_only: desc.match?(/\(mc only\)/i),
          skip: (clauses.empty? ? skip_reason(desc) : nil), clauses: clauses }
      end

      # ---- internals -------------------------------------------------------

      def self.skip_reason(desc)
        SKIP_PATTERNS.each { |reason, re| return reason if desc.match?(re) }
        nil
      end

      # Split into fine clauses on separators and "and"/"plus". Split on comma only when
      # followed by a space, so digit-grouping commas ("100,000") stay intact.
      def self.split_clauses(body)
        # <br/> first so it isn't mistaken for the "/" clause separator; it separates the stat
        # clauses in tiered skills (e.g. "…max HP.<br/>10% Bonus Destruction C.A. DMG").
        body.split(%r{<br\s*/?>|\s*/\s*|,\s+|\s+and\s+|\s+plus\s+}i).map(&:strip).reject(&:empty?)
      end

      # [boost_type, formula] pairs for a fragment. A HP-/turn-scaling phrase converts the base
      # stat to its scaling boost (ATK→enmity/stamina/e_atk_prog, DEF→Garrison), and the "HP"
      # mentioned in the condition is dropped (it's the scaling basis, not a boost target).
      def self.boosts_for(frag)
        scaling = scaling_for(frag)
        boosts = boost_consume(frag)
        return boosts.map { |b| [b, "flat"] } unless scaling

        (boosts - ["hp"]).map { |b| scale_boost(b, scaling) }
      end

      def self.scale_boost(boost, scaling)
        return ["enmity", "enmity"] if boost == "atk" && scaling == :low_hp
        return ["stamina", "stamina"] if boost == "atk" && scaling == :high_hp
        return ["e_atk_prog", "progression"] if boost == "atk" && scaling == :turns
        return ["def", "garrison"] if boost == "def" && scaling == :low_hp

        [boost, "flat"]
      end

      def self.scaling_for(frag)
        return :low_hp if frag.match?(/based on how low .*hp|the lower .*hp/i)
        return :high_hp if frag.match?(/based on how high .*hp|the higher .*hp/i)
        return :turns if frag.match?(/number of turns|each turn|every turn|per turn|turns? (?:passed|elapsed)/i)
        nil
      end

      # All boost_types in a fragment, matched specific→general with consumption.
      def self.boost_consume(frag)
        rest = " #{frag} "
        found = []
        BOOST_PATTERNS.each do |re, key|
          next unless rest =~ re

          found.concat(Array(key))
          rest = rest.sub(re, " ")
        end
        found.uniq
      end

      def self.explicit?(frag)
        frag.match?(/\d/) # a number present ⇒ flat value, not an SL-scaled size tier
      end

      # Explicit value: a percentage, or a "by 100,000" supplement amount.
      def self.value_for(frag, boost)
        if %w[dmg_supp na_supp ca_supp skill_dmg_supp].include?(boost) && (m = frag[/by\s+([\d,]+)/i, 1])
          return m.delete(",").to_f
        end
        (m = frag[/(\d+(?:\.\d+)?)\s*%/, 1]) ? m.to_f : nil
      end

      # Series from an aura-word in the skill NAME (possessive "Inferno's", leading "Amber Arts",
      # or multi-word "Taboo Allowater's …"), an explicit "EX/Omega modifier" annotation, else
      # normal. (Never the icon.)
      def self.series_for(desc, name)
        text = "#{name} #{desc}"
        # Odious skills are NAMED "Taboo <element>'s …"; match Taboo in the NAME only — the word
        # also appears in ≥280 condition prose ("…wind Taboo… weapon skills") on EX skills.
        return "odious" if name.to_s.match?(/\btaboo\b/i)
        return "omega" if text.match?(/\bomega modifier\b/i)
        return "ex" if text.match?(/\bex modifier\b/i)

        parsed = name.present? ? WeaponSkillParser.parse(name) : {}
        return parsed[:series] if parsed[:series] # core element aura-word → normal/omega/ex/odious

        # No core element aura-word. A BARE aura-boostable modifier (no aura prefix — e.g.
        # "Tyranny", "Celere" on Optimus grid weapons, element templated away) is Normal.
        # Everything else — flavor names ("Psycho's Might"), non-core auras (Ultima, Militis,
        # Astral, …), and flat/unknown modifiers — is NOT aura-boosted ⇒ EX.
        return "normal" if parsed[:aura].nil? && WeaponSkillParser::BOOSTABLE_MODIFIERS.include?(parsed[:modifier])

        "ex"
      end

      # Light structured condition from common phrasings (extended as needed).
      def self.condition_for(frag)
        return { "type" => "weapon_group_count", "gte" => 0, "all" => true } if frag.match?(/all weapon groups/i)
        nil
      end

      def self.clean(text)
        return "" if text.blank?

        s = text.dup
        s.gsub!(/<ref[^>]*>.*?<\/ref>/m, "")
        s.gsub!(/<ref[^>]*\/>/, "")
        s.gsub!(/\{\{tt\|([^|}]+)\|[^}]*\}\}/i, '\1') # {{tt|text|tooltip}} → text
        s.gsub!(/\{\{status\|([^|}]+)[^}]*\}\}/i, '\1')
        s.gsub!(/\{\{[^{}]*\}\}/m, "")
        s.gsub!(/'''|''/, "")
        s.gsub!(%r{<br\s*/?>}i, " / ") # clause separator in tiered skills — keep it, don't blank it
        s.gsub!(/<[^>]+>/, " ")
        s.gsub(/\s+/, " ").strip
      end

      def self.blank_result
        { main_hand_only: false, mc_only: false, skip: nil, clauses: [] }
      end

      private_class_method :skip_reason, :split_clauses, :boosts_for, :scale_boost, :scaling_for,
                           :boost_consume, :explicit?, :value_for, :condition_for,
                           :clean, :blank_result
    end
  end
end
