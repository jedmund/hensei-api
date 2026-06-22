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
    #   aurat0..5 -> (5, n+1)   (transcendence levels 200–250; stage mapping validated in calc phase)
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
            rec = build(txt, slot:, uncap_level: uncap, transcendence_stage: 0,
                        series:, summon_element: element, granblue_id:)
            records << rec if rec
          end
          (0..5).each do |n|
            txt = fields["#{prefix}aurat#{n}"]
            rec = build(txt, slot:, uncap_level: 5, transcendence_stage: n + 1,
                        series:, summon_element: element, granblue_id:)
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
      TARGET_PRIORITY = %w[normal_frame omega_frame elemental_atk normal_atk omega_atk multiattack atk other].freeze

      def build(text, slot:, uncap_level:, transcendence_stage:, series:, summon_element:, granblue_id:)
        return nil if text.blank?

        clean = strip_markup(text)
        return nil if clean.blank?

        # An aura can carry several clauses ("…HP.<br />…Elemental ATK / …"); classify
        # each and keep the most grid-relevant (frame > elemental > … > other).
        clauses = clean.split(%r{<br\s*/?>|\s/\s|\.\s+(?=[A-Z])}).map(&:strip).reject(&:blank?)
        clauses = [clean] if clauses.empty?
        best = clauses.map { |c| parse_clause(c, series:, summon_element:) }
                      .min_by { |pc| TARGET_PRIORITY.index(pc[:target]) }

        {
          summon_granblue_id: granblue_id, slot:, target: best[:target], element: best[:element],
          value: best[:value], uncap_level:, transcendence_stage:,
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

        target, element = classify(phrase, series:, summon_element:)
        condition ||= detect_condition(clause)
        { target:, element:, value:, condition: }
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
          return ["omega_frame", nil] if OMEGA_WORDS.any? { |w| p.include?(w) } || series == "magna"
          return ["normal_frame", nil]
        end
        return ["normal_atk", nil] if p.include?("normal atk")
        return ["omega_atk", nil] if p.include?("omega atk")
        return ["multiattack", nil] if p.include?("multiattack")
        # ATK boosts: the wiki writes "[element] Elemental ATK", "[element] ATK", or
        # "[element] Elemental attack" (varied phrasing) — all feed the Elemental
        # category. Guard against "charge attack" (CA) and "attack critical" (crit).
        # Element-less generic "ATK" is an ATK-up buff (target "atk"; flagged for panel
        # validation).
        attack_ish = (p =~ /\b(atk|attack)\b/) && !p.include?("charge attack") && !p.include?("critical")
        if attack_ish || p.include?("elemental atk")
          el = elements_in(p)
          return ["elemental_atk", el || summon_element] if el || p.include?("elemental")

          return ["atk", nil]
        end

        ["other", nil]
      end

      # "Dark and Earth" -> "dark,earth"; "all" -> "all"; else nil.
      def elements_in(phrase)
        return "all" if phrase =~ /\ball\b/
        found = ELEMENTS.select { |e| phrase.include?(e) }
        found.any? ? found.join(",") : nil
      end

      def detect_condition(text)
        t = text.downcase
        return "main_summon" if t.include?("main summon")
        return "per_weapon_group" if t.include?("weapon group")

        nil
      end
    end
  end
end
