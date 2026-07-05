# frozen_string_literal: true

module Granblue
  module Parsers
    # Parses the "Gameplay Notes" section of an EXPANDED weapon template (action=expandtemplates).
    # That section carries the community-computed skill values that the in-game / skill-blurb
    # prose omits — e.g. Twinpain's "8% ATK per Gun (Max 80%)" and Cloud's per-specialty table.
    #
    # Output: { skill_name => { frame:, clauses: [ ... ] } } where each clause is one of:
    #   { boost_type:, scaling: :per_count, value:, max:, count_unit:, shared_cap:, sp: }
    #   { boost_type:, scaling: :per_specialty, by_specialty: { "gun"=>40.0, "other"=>20.0, ... } }
    #   { boost_type:, scaling: :flat, value: }
    class GameplayNotesParser
      # Prose phrases AND table `data-label`s → boost_type. One map, reused for both.
      LABEL_TO_BOOST = {
        "ex might" => "atk", "omega might" => "atk", "might" => "atk", "atk" => "atk",
        "e. atk" => "e_atk", "e.atk" => "e_atk", "elemental atk" => "e_atk",
        "stamina" => "stamina", "enmity" => "enmity",
        "da rate" => "da", "da" => "da", "double attack" => "da", "double attack rate" => "da",
        "ta rate" => "ta", "ta" => "ta", "triple attack" => "ta", "triple attack rate" => "ta",
        "na dmg cap" => "na_dmg_cap", "normal attack damage cap" => "na_dmg_cap",
        "critical" => "critical", "critical hit rate" => "critical",
        "c.a. dmg" => "ca_dmg", "c.a. specs" => "ca_dmg", "charge attack dmg" => "ca_dmg",
        "c.a. dmg cap" => "ca_dmg_cap", "dmg cap" => "dmg_cap", "damage cap" => "dmg_cap",
        "skill dmg cap" => "skill_dmg_cap", "hp" => "hp", "def" => "def",
        "dmg amp" => "dmg_amp", "crit amp" => "crit_amp"
      }.freeze

      # Skill modifiers whose EX ATK occupies the secondary "(Sp.)" multiplier slot (EX Might Sp.)
      # rather than the primary one. (gbf.wiki Damage Formula — Voltage is the canonical case.)
      SP_ATK_MODIFIERS = [/voltage/i].freeze

      def self.parse(expanded)
        idx = expanded.to_s =~ /Gameplay Notes/i
        return {} unless idx

        out = {}
        # Sections are wikitext sub-headers: === Skill Name === ... (until the next header / end).
        expanded[idx..].scan(/^={2,4}\s*(.+?)\s*={2,4}\s*\n(.*?)(?=^={2,4}|\z)/m).each do |name, body|
          skill = clean(name)
          next if skill.blank? || skill =~ /gameplay notes/i

          clauses = parse_section(skill, body)
          out[skill] = { frame: frame_of(body), clauses: clauses } if clauses.any?
        end
        out
      end

      def self.parse_section(skill, body)
        clauses = []
        clauses.concat(per_count_clauses(skill, body))
        clauses.concat(specialty_clauses(body))
        clauses.concat(progression_clauses(body))
        clauses.concat(tier_clauses(body))
        clauses
      end

      # "N% boost to STAT (Max: M%) ... per <unit> weapon" → a per-grid-count clause.
      def self.per_count_clauses(skill, body)
        body.scan(/(\d+(?:\.\d+)?)%\s*boost to\s*(.+?)\s*\(Max:\s*(\d+(?:\.\d+)?)%\).*?per\s*(?:\[\[[^\]|]*\|)?([A-Za-z][A-Za-z .]*?)\b/im).filter_map do |val, stat, max, unit| # rubocop:disable Layout/LineLength
          bt = boost_for(stat) or next
          bt = "ex_atk_sp" if bt == "atk" && SP_ATK_MODIFIERS.any? { |re| skill =~ re }
          { boost_type: bt, scaling: :per_count, value: val.to_f, max: max.to_f,
            count_unit: unit.strip.downcase, shared_cap: shared_cap_of(body) }
        end
      end

      SPECIALTIES = %w[gun other sabre dagger spear axe bow staff melee harp katana].freeze

      # A {| wikitable with specialty-named rows → per-specialty values per stat column.
      def self.specialty_clauses(body)
        table = body[/\{\|.*?\|\}/m] or return []
        labels = table.scan(/data-label="([^"]+)"/).flatten.map { |l| boost_for(l) }
        return [] if labels.compact.empty?

        rows = data_rows(table).select { |c| SPECIALTIES.include?(c.first.to_s.downcase) }
        return [] if rows.empty?

        labels.each_with_index.filter_map do |bt, col|
          next unless bt

          by_spec = rows.to_h { |c| [c.first.downcase, pct(c[col + 1])] }.compact
          { boost_type: bt, scaling: :per_specialty, by_specialty: by_spec } if by_spec.any?
        end
      end

      # A "Skill Level | per Turn | Max | …" table → a progression boost (value grows per turn).
      def self.progression_clauses(body)
        table = body[/\{\|.*?\|\}/m] or return []
        return [] unless /per Turn/i.match?(table)

        bt = boost_for(table.scan(/data-label="([^"]+)"/).flatten.first.to_s) || "atk"
        rows = data_rows(table).select { |c| c.first.to_s =~ /\A\d+\z/ } # Skill Level rows
        by_level = rows.to_h { |c| [c.first.to_i, pct(c[1])] }.compact
        return [] if by_level.empty?

        max = rows.filter_map { |c| pct(c[2]) }.max
        [{ boost_type: bt, scaling: :progression, by_level: by_level, max: max }]
      end

      # A "Skill Tier | [Affects] | <stat> | <stat>" table (e.g. Godblade I/II/III) → per-tier
      # values, indexed by tier ordinal (1 = lowest uncap, last = highest).
      def self.tier_clauses(body)
        table = body[/\{\|.*?\|\}/m] or return []
        labels = table.scan(/data-label="([^"]+)"/).flatten.map { |l| boost_for(l) }
        return [] if labels.compact.empty?

        rows = data_rows(table).select { |c| c.first.to_s =~ /\b[IVX]+\z/ } # "<Name> III"
        return [] if rows.empty?

        labels.each_with_index.filter_map do |bt, idx|
          next unless bt

          by_tier = rows.each_with_index.to_h do |c, tier_i|
            nums = c.drop(1).filter_map { |x| pct(x) } # skip name + any non-numeric "Affects"
            [tier_i + 1, nums[idx]]
          end.compact
          { boost_type: bt, scaling: :tier, by_tier: by_tier } if by_tier.any?
        end
      end

      # Wikitable → array of data-row cell arrays (header/style rows excluded).
      def self.data_rows(table)
        table.split('|-').filter_map do |row|
          cells = row.split(/\|\||\n\s*[!|]/).map { |c| clean(c) }.reject(&:empty?)
          cells if cells.size > 1 && cells.first !~ /wikitable|style=/
        end
      end

      # Inline "N% boost to <stat>" pairs from prose where the stat is a `data-label` icon (kept
      # as text) or plain words — e.g. a Dark Opus ≥280 Effect cell. → [{boost_type, value, series}]
      # (series inferred from the ATK label: EX Might → ex, Omega Might → omega, Might → normal).
      # "Amplify <target> DMG by N%" targets → amp boost keys.
      AMPLIFY_TARGETS = [
        [/normal attack|n\.?a\.?/i, "na_amp"],
        [/c\.?a\.?|charge attack/i, "ca_amp"],
        [/skill/i, "skill_amp"]
      ].freeze

      def self.inline_boosts(text)
        labeled = text.to_s
                      # {{atkmod|ATK|m=ex}} → "EX Might" (carries the boost AND the frame)
                      .gsub(/\{\{\s*atkmod\s*\|[^|}]*\|?\s*m\s*=\s*ex[^}]*\}\}/i, " EX Might ")
                      .gsub(/\{\{\s*atkmod\s*\|[^|}]*\|?\s*m\s*=\s*omega[^}]*\}\}/i, " Omega Might ")
                      .gsub(/\{\{\s*atkmod\s*\|[^}]*\}\}/i, " Might ")
                      # {{tt|Amplify|'''Stacking:''' Special}} → "Amplify(Sp.)" — the tooltip marks
                      # the panel's second-stack "(Sp.)" instance (e.g. Extremity's N.A. Amp (Sp.)).
                      .gsub(/\{\{\s*tt\s*\|\s*([^|}]+?)\s*\|[^}]*Special[^}]*\}\}/i, ' \1(Sp.) ')
                      .gsub(/\{\{\s*tt\s*\|\s*([^|}]+?)\s*\|[^}]*\}\}/i, ' \1 ')
                      .gsub(%r{<span[^>]*data-label="([^"]+)"[^>]*>(?:\s*</span>)?}i, ' \1 ')
                      .gsub(/<[^>]+>/, " ")
        boosts = labeled.scan(%r{(\d+(?:\.\d+)?)%\s*boost to\s*([A-Za-z.][A-Za-z. ]*?)(?=\s*\d|,|\.|/|\z)}).filter_map do |value, stat|
          bt = boost_for(stat) or next

          series = case stat.downcase
                   when /\bex\b/ then "ex"
                   when /omega/ then "omega"
                   when /\bmight\b/ then "normal"
                   end
          { boost_type: bt, value: value.to_f, series: series }
        end
        boosts + amplify_boosts(labeled)
      end

      # "Amplify normal attack DMG by 10%" ((Sp.)-stacked or not) → amp boost entries.
      def self.amplify_boosts(labeled)
        labeled.scan(/Amplify(\(Sp\.\))?\s+([A-Za-z. ]+?)\s+by\s+(\d+(?:\.\d+)?)%/i).filter_map do |sp, target, value|
          base = AMPLIFY_TARGETS.find { |re, _| target =~ re }&.last || "dmg_amp"
          { boost_type: sp ? "#{base}_sp" : base, value: value.to_f, series: nil }
        end
      end

      def self.boost_for(text)
        key = clean(text).downcase.sub(/\s*boost.*$/, "").strip
        LABEL_TO_BOOST[key] || LABEL_TO_BOOST[key.sub(/^all allies'?\s*/, "")]
      end

      def self.frame_of(body)
        body[/Multiplier:[^.<]*?\b(Normal|EX|Omega|Od)\b/i, 1]&.downcase&.sub("od", "odious")
      end

      def self.shared_cap_of(body)
        return nil unless /share the same cap/i.match?(body)

        names = body.scan(/''([A-Za-z .]+?)''/).flatten.map { |n| n.strip.downcase.gsub(/[^a-z]+/, "_") }
        names.reject(&:empty?).uniq.join("_").presence
      end

      def self.pct(cell)
        return nil if cell.nil? || cell.strip == "-"

        cell[/\d+(?:\.\d+)?/]&.to_f
      end

      def self.clean(html)
        html.to_s.gsub(/<[^>]+>/, "").gsub(/\[\[[^\]|]*\|?([^\]]*)\]\]/, '\1')
            .gsub(%r{<ref[^>]*>.*?</ref>}m, "").gsub(/'''|''|[{}!]/, "").gsub(/\s+/, " ").strip
      end

      private_class_method :parse_section, :per_count_clauses, :specialty_clauses, :progression_clauses, :tier_clauses, :data_rows, :boost_for,
                           :amplify_boosts, :frame_of, :shared_cap_of, :pct, :clean
    end
  end
end
