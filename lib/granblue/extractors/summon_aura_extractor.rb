# frozen_string_literal: true

require Rails.root.join("lib/granblue/parsers/weapon_skill_parser")

module Granblue
  module Extractors
    # Parses a summon's wiki_raw ({{Summon|...}} template) into per-tier aura records
    # for the summon_auras table. The aura TYPE is read from the wording (validated
    # against the in-game panel), not guessed:
    #
    #   "X% boost to <Ironflame/Inferno…>'s weapon skills" -> frame multiplier
    #       (omega_frame if an omega aura-word is present, else normal_frame)
    #   "X% boost to <element> Elemental ATK"              -> elemental_atk
    #   "Boost to Normal/Omega ATK (Max: X%) …"            -> normal_atk / omega_atk
    #   "… multiattack rate …"                             -> multiattack
    #   anything else (charge bar, call, cap…)             -> other
    #
    # Tier -> (uncap_level, transcendence_stage):
    #   aura1 -> (0,0)  aura2 -> (3,0)  aura3 -> (4,0)  aura4 -> (5,0)   [Template:Summon]
    #   auratN -> (5, N) for N in 1..5   (transcendence stages; stored as the wiki numbers them)
    #   aurat0 is never read: it would collide with aura4's (5, 0) row, and no summon page uses it.
    class SummonAuraExtractor
      NORMAL_WORDS = Granblue::Parsers::WeaponSkillParser::NORMAL_AURAS.map(&:downcase).freeze
      OMEGA_WORDS  = Granblue::Parsers::WeaponSkillParser::OMEGA_AURAS.map(&:downcase).freeze
      ELEMENTS = %w[fire water earth wind light dark].freeze
      BASE_TIER = { 1 => 0, 2 => 3, 3 => 4, 4 => 5 }.freeze # auraN -> uncap_level

      # granblue_id: the summon's id; series: summon_series slug; element: summon element word.
      def extract(wikitext, granblue_id:, series: nil, element: nil)
        fields = parse_fields(wikitext)
        records = []

        [["", "main"], ["sub", "sub"]].each do |prefix, slot|
          BASE_TIER.each do |n, uncap|
            txt = fields["#{prefix}aura#{n}"]
            rec = build(txt, slot: slot, uncap_level: uncap, transcendence_stage: 0,
                        series: series, summon_element: element, granblue_id: granblue_id)
            records << rec if rec
          end
          (1..5).each do |n|
            txt = fields["#{prefix}aurat#{n}"]
            rec = build(txt, slot: slot, uncap_level: 5, transcendence_stage: n,
                        series: series, summon_element: element, granblue_id: granblue_id)
            records << rec if rec
          end
        end

        records
      end

      private

      # Scan |key=value template params (aura values are single-line).
      def parse_fields(wikitext)
        fields = {}
        wikitext.to_s.each_line do |line|
          fields[Regexp.last_match(1).downcase] = Regexp.last_match(2) if line =~ /\A\s*\|\s*([a-z0-9_]+)\s*=\s*(.*?)\s*\z/i
        end
        fields
      end

      # Most grid-relevant first — multi-clause auras keep the highest-priority clause.
      TARGET_PRIORITY = %w[normal_frame omega_frame odious_frame elemental_atk normal_atk omega_atk multiattack atk other].freeze
      private_constant :TARGET_PRIORITY

      # Conditions that only hold in some battle states; a clause carrying one loses a
      # target tie to an always-on clause.
      SITUATIONAL = %w[defense_order].freeze
      private_constant :SITUATIONAL

      def build(text, slot:, uncap_level:, transcendence_stage:, series:, summon_element:, granblue_id:) # rubocop:disable Metrics/ParameterLists
        return nil if text.blank?

        clean = strip_markup(text)
        return nil if clean.blank?

        # An aura can carry several clauses ("…HP.<br />…Elemental ATK / …"); classify
        # each and keep the most grid-relevant (frame > elemental > … > other).
        clauses = clean.split(%r{<br\s*/?>|\s/\s|\.\s+(?=[A-Z])}).map(&:strip).reject(&:blank?)
        clauses = [clean] if clauses.empty?
        # Ties on target go to the unconditional clause ("40% boost to ATK" over "During
        # Defense Order: 80% boost to ATK"), then to the earlier clause.
        best = clauses.map { |c| parse_clause(c, series: series, summon_element: summon_element) }
                      .each_with_index
                      .min_by { |pc, i| [TARGET_PRIORITY.index(pc[:target]), SITUATIONAL.include?(pc[:condition]) ? 1 : 0, i] }
                      .first

        {
          summon_granblue_id: granblue_id, slot: slot, target: best[:target], element: best[:element],
          value: best[:value], uncap_level: uncap_level, transcendence_stage: transcendence_stage,
          condition: best[:condition], description_en: clean.strip
        }
      end

      def parse_clause(clause, series:, summon_element:)
        value = nil
        condition = nil
        if clause =~ /(\d+(?:\.\d+)?)%\s*boost to\s+(.+)/i
          value = Regexp.last_match(1).to_f
          phrase = Regexp.last_match(2)
        elsif clause =~ /boost to\s+(.+?)\s*\(max:\s*(\d+(?:\.\d+)?)%\)/i
          phrase = Regexp.last_match(1)
          value = Regexp.last_match(2).to_f
          condition = "variable"
        else
          phrase = clause
        end

        target, element = classify(phrase, series: series, summon_element: summon_element)
        condition ||= detect_condition(clause)
        { target: target, element: element, value: value, condition: condition }
      end

      def strip_markup(text)
        text.to_s
            .gsub(/\[\[[^\]|]*\|([^\]]*)\]\]/, '\1') # [[Page|label]] -> label
            .gsub(/\[\[([^\]]*)\]\]/, '\1')          # [[Page]] -> Page
            .gsub(/\{\{tt\|([^|}]*)\|[^}]*\}\}/, '\1') # {{tt|text|tip}} -> text
            .strip
      end

      def classify(phrase, series:, summon_element:)
        p = phrase.downcase
        if p.include?("weapon skill")
          # Odious summons boost "Taboo <X>'s weapon skills" — the Odious frame, not Optimus.
          return ["odious_frame", nil] if p.include?("taboo") || series == "odious"
          return ["omega_frame", nil] if OMEGA_WORDS.any? { |w| p.include?(w) } || series == "magna"
          return ["normal_frame", nil]
        end
        # A DMG cap or a damage supplement is not an ATK boost, even when it names
        # "normal attack" ("5% boost to light allies' normal attack DMG cap").
        return ["other", nil] if cap_or_supplement?(p)
        return ["normal_atk", nil] if /\bnormal (atk|attack)\b(?!\s+(dmg|damage))/.match?(p)
        return ["omega_atk", nil] if p.include?("omega atk")
        return ["multiattack", nil] if p.include?("multiattack") || da_ta_rate?(p)
        # Battle-start statuses ("starts battle with … ATK Up") and boosts to named
        # characters ("Gachapin's ATK", "Cinderella girls' ATK") don't scale the grid.
        return ["other", nil] if p =~ /\bstarts? battle with\b/ || restricted_subject?(p)

        # ATK boosts: the wiki writes "[element] Elemental ATK", "[element] ATK", or
        # "[element] Elemental attack" (varied phrasing) — all feed the Elemental
        # category. Guard against "charge attack" (CA) and "attack critical" (crit).
        # A subject-less "X% boost to ATK" is party-wide, like "all allies' ATK".
        # Other element-less ATK is an ATK-up buff (target "atk"; flagged for panel
        # validation).
        attack_ish = (p =~ /\b(atk|attack)\b/) && !p.include?("charge attack") && !p.include?("critical")
        if attack_ish || p.include?("elemental atk")
          el = elements_in(p)
          return ["elemental_atk", el || summon_element] if el || p.include?("elemental")
          return %w[elemental_atk all] if /\A(atk|attack)\b/.match?(p)

          return ["atk", nil]
        end

        ["other", nil]
      end

      # The boosted noun: the phrase up to the first comma or period. Tests that look only
      # at it keep a later "… C.A. DMG Cap" or "penalty to Double Attack Rate" in the same
      # sentence from reclassifying "80% boost to Light Elemental ATK, …".
      def head(phrase)
        phrase[/\A[^,.]*/]
      end

      def cap_or_supplement?(phrase)
        phrase.start_with?("supplement") || /\b(dmg|damage) cap\b/.match?(head(phrase))
      end

      # "boost to double attack rate", not a "{{status|Triple Attack Rate Boosted}}" grant.
      def da_ta_rate?(phrase)
        /(?<!\|)\b(double|triple) attack rate\b/.match?(head(phrase))
      end

      # "X's ATK" / "Xs' ATK" where X is neither an element nor allies (MC's, Gachapin's,
      # Cinderella girls', Lumiel Order characters'). "{{atkmod|ATK…}}" may sit between.
      def restricted_subject?(phrase)
        owner = phrase[/(\S+?)(?:'s|')\s+(?:\{\{atkmod\|)?(?:elemental\s+)?(?:atk|attack)\b/, 1]
        return false unless owner

        !(ELEMENTS + %w[all ally allies]).include?(owner)
      end

      # "Dark and Earth" -> "dark,earth"; "all" -> "all"; else nil.
      def elements_in(phrase)
        return "all" if /\ball\b/.match?(phrase)
        found = ELEMENTS.select { |e| phrase.include?(e) }
        found.any? ? found.join(",") : nil
      end

      def detect_condition(text)
        t = text.downcase
        return "main_summon" if t.include?("main summon")
        return "per_weapon_group" if t.include?("weapon group")
        return "defense_order" if t.include?("defense order")

        nil
      end
    end
  end
end
