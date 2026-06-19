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

      # Ordered (specific → general) phrase → boost_type. Within a clause we match-and-consume
      # so a specific phrase ("skill DMG cap") prevents the general one ("DMG cap") re-matching.
      BOOST_PATTERNS = [
        [/skill (?:dmg|damage) cap/i,                        "skill_dmg_cap"],
        [/(?:normal attack|n\.?a\.?) (?:dmg|damage) cap/i,   "na_dmg_cap"],
        [/(?:charge attack|c\.?a\.?) (?:dmg|damage) cap/i,   "ca_dmg_cap"],
        [/(?:dmg|damage) cap/i,                              "dmg_cap"],
        [/amplify (?:normal attack|n\.?a\.?)/i,              "na_amp"],
        [/amplify (?:charge attack|c\.?a\.?)/i,              "ca_amp_sp"],
        [/amplify skill/i,                                   "skill_amp_sp"],
        [/(?:elemental .*amplif|amplify elemental)/i,        "elem_amplify"],
        [/amplif/i,                                          "dmg_amp"],
        [/supplement.*(?:charge attack|c\.?a\.?)/i,          "ca_supp"],
        [/supplement.*skill/i,                               "skill_dmg_supp"],
        [/supplement.*(?:normal attack|n\.?a\.?)/i,          "na_supp"],
        [/supplement/i,                                      "dmg_supp"],
        [/bonus.*(?:charge attack|c\.?a\.?)/i,               "bonus_ca"],
        [/bonus.*(?:dmg|damage)/i,                           "bonus_elem_dmg"],
        [/hit to (?:multiattack|double attack|triple attack)|multiattack rate/i, "multiattack"],
        [/double attack rate|\bda rate\b/i,                  "da"],
        [/triple attack rate|\bta rate\b/i,                  "ta"],
        [/critical/i,                                        "critical"],
        [/boost to charge bar gain|charge bar gain (?:boost|up)/i, "charge_gain"],
        [/(?:dmg|damage) (?:cut|reduc)/i,                    "elem_reduc"],
        [/(?:charge attack|c\.?a\.?) (?:dmg|damage)/i,       "ca_dmg"],
        [/\bdef(?:ense)?\b/i,                                "def"],
        [/max hp|\bhp\b/i,                                   "hp"],
        [/\batk\b/i,                                         "atk"]
      ].freeze

      AURA_TO_SERIES = WeaponSkillParser::AURA_TO_SERIES

      def self.parse(description, name: nil)
        desc = clean(description)
        return blank_result if desc.blank?

        body = desc.sub(/\Awhen main weapon[^:]*:/i, "").sub(/\A[^:]*\(mc only\)[^:]*:/i, "")
        series0 = series_for(desc, name)

        clauses = []
        last_size = nil
        split_clauses(body).each do |frag|
          size = frag[SIZE_KEYWORD, 1]&.downcase || last_size
          last_size = size if frag.match?(SIZE_KEYWORD)
          formula = formula_for(frag)
          boost_consume(frag).each do |boost|
            clauses << {
              boost_type: boost, value: value_for(frag, boost), size: (size unless explicit?(frag)),
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
        body.split(%r{\s*/\s*|,\s+|\s+and\s+|\s+plus\s+}i).map(&:strip).reject(&:empty?)
      end

      # All boost_types in a fragment, matched specific→general with consumption.
      def self.boost_consume(frag)
        rest = " #{frag} "
        found = []
        BOOST_PATTERNS.each do |re, key|
          next unless rest =~ re

          found << key
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

      def self.formula_for(frag)
        return "enmity" if frag.match?(/based on how low .*hp|the lower .*hp/i)
        return "stamina" if frag.match?(/based on how high .*hp|the higher .*hp/i)
        return "progression" if frag.match?(/each turn|every turn|per turn/i)
        "flat"
      end

      # Series from an aura-word in the name/description, an explicit "EX/Omega modifier"
      # annotation, else normal. (Never the icon.)
      def self.series_for(desc, name)
        text = "#{name} #{desc}"
        return "ex" if text.match?(/\bex modifier\b/i)
        return "omega" if text.match?(/\bomega modifier\b/i)
        AURA_TO_SERIES.each { |aura, ser| return ser.to_s if text.match?(/\b#{Regexp.escape(aura)}'s\b/) }
        "normal"
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
        s.gsub!(/<[^>]+>/, " ")
        s.gsub(/\s+/, " ").strip
      end

      def self.blank_result
        { main_hand_only: false, mc_only: false, skip: nil, clauses: [] }
      end

      private_class_method :skip_reason, :split_clauses, :boost_consume, :explicit?, :value_for,
                           :formula_for, :series_for, :condition_for, :clean, :blank_result
    end
  end
end
