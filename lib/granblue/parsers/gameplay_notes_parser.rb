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
        "da rate" => "da", "da" => "da", "double attack" => "da",
        "ta rate" => "ta", "ta" => "ta", "triple attack" => "ta",
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
        clauses
      end

      # "N% boost to STAT (Max: M%) ... per <unit> weapon" → a per-grid-count clause.
      def self.per_count_clauses(skill, body)
        body.scan(/(\d+(?:\.\d+)?)%\s*boost to\s*(.+?)\s*\(Max:\s*(\d+(?:\.\d+)?)%\).*?per\s*(?:\[\[[^\]|]*\|)?([A-Za-z][A-Za-z .]*?)\b/im).filter_map do |val, stat, max, unit|
          bt = boost_for(stat) or next
          bt = "ex_atk_sp" if bt == "atk" && SP_ATK_MODIFIERS.any? { |re| skill =~ re }
          { boost_type: bt, scaling: :per_count, value: val.to_f, max: max.to_f,
            count_unit: unit.strip.downcase, shared_cap: shared_cap_of(body) }
        end
      end

      # A {| wikitable with a "Specialty" header → per-specialty values per stat column.
      def self.specialty_clauses(body)
        table = body[/\{\|.*?\|\}/m] or return []
        labels = table.scan(/data-label="([^"]+)"/).flatten.map { |l| boost_for(l) }
        return [] if labels.compact.empty?

        rows = table.split(/\|-/).filter_map do |row|
          cells = row.split(/\|\||\n\s*\|/).map { |c| clean(c) }.reject(&:empty?)
          next unless cells.first && %w[gun other sabre dagger spear axe bow staff melee harp katana].include?(cells.first.downcase)

          [cells.first.downcase, cells[1..]]
        end
        return [] if rows.empty?

        labels.each_with_index.filter_map do |bt, col|
          next unless bt

          by_spec = rows.to_h { |spec, vals| [spec, pct(vals[col])] }.compact
          { boost_type: bt, scaling: :per_specialty, by_specialty: by_spec } if by_spec.any?
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
        return nil unless body =~ /share the same cap/i

        names = body.scan(/''([A-Za-z .]+?)''/).flatten.map { |n| n.strip.downcase.gsub(/[^a-z]+/, "_") }
        names.reject(&:empty?).uniq.join("_").presence
      end

      def self.pct(cell)
        return nil if cell.nil? || cell.strip == "-"

        cell[/\d+(?:\.\d+)?/]&.to_f
      end

      def self.clean(html)
        html.to_s.gsub(/<[^>]+>/, "").gsub(/\[\[[^\]|]*\|?([^\]]*)\]\]/, '\1')
            .gsub(/<ref[^>]*>.*?<\/ref>/m, "").gsub(/'''|''|[{}!]/, "").gsub(/\s+/, " ").strip
      end

      private_class_method :parse_section, :per_count_clauses, :specialty_clauses, :boost_for,
                           :frame_of, :shared_cap_of, :pct, :clean
    end
  end
end
