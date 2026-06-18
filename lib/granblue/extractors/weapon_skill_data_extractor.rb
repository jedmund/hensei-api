# frozen_string_literal: true

module Granblue
  module Extractors
    # Parses a `Template:Weapon Skills/<Name>` WsBox wikitext into
    # weapon_skill_data row hashes. Pure function of the wikitext + a
    # boost-name→key map; see docs/damage/08-scaling-data-pipeline.md.
    #
    #   rows = WeaponSkillDataExtractor.new.extract(wikitext, name: "Might")
    #
    # Each row: { modifier, boost_type, series, size, formula_type,
    #             sl1, sl10, sl15, sl20, sl25, coefficient, max_value, aura_boostable }
    class WeaponSkillDataExtractor
      SIZE_MAP = {
        "small" => "small", "medium" => "medium", "big" => "big",
        "big ii" => "big_ii", "big2" => "big_ii", "massive" => "massive",
        "unworldly" => "unworldly", "ancestral" => "ancestral"
      }.freeze

      # boost_type key → formula_type (anything else is flat)
      FORMULA_BY_BOOST = {
        "enmity" => "enmity", "stamina" => "stamina", "e_atk_prog" => "progression"
      }.freeze

      SERIES_PREFIXES = ["Omega ", "EX ", "Od ", "Normal "].freeze

      # Series detection from a wsmod title row (by aura icon, then label word).
      def self.series_for_title(title)
        t = title.downcase
        return "taboo" if t.include?("taboo")
        return "sephira" if t.include?("sephira")
        has_normal = t.include?("normal aura") || t =~ /\bnormal\b/
        has_omega  = t.include?("omega aura")  || t =~ /\bomega\b/
        return "normal_omega" if has_normal && has_omega
        return "odious" if t.include?("odious")
        return "omega" if has_omega
        return "ex" if t =~ /\bex\b/
        return "normal" if has_normal
        nil
      end

      def initialize(boost_key_by_name: nil)
        @key_by_name = boost_key_by_name || self.class.default_key_map
      end

      # Build the boost-name→key map from the DB plus the one non-name_en alias.
      def self.default_key_map
        map = WeaponSkillBoostType.pluck(:name_en, :key).to_h
        map["Might"] = "atk" # ATK family: Might/Omega Might/EX Might/Od Might → atk
        map
      end

      def extract(wikitext, name:)
        wikitext = wikitext.gsub(/<!--.*?-->/m, "") # strip multi-line comments first
        box = parse_box(wikitext)
        modifier = (box[:name] || name).strip
        aura = box[:aura_boostable] == "yes" || box[:aura_boostable] == "both"

        rows = []
        rows.concat(stamina_rows(wikitext, modifier, aura))
        rows.concat(grid_rows(wikitext, modifier, aura))
        # de-dupe on the uniqueness key, last wins
        rows.uniq! { |r| [r[:modifier], r[:boost_type], r[:series], r[:size]] }
        rows
      end

      private

      # ---- WsBox params ----------------------------------------------------
      def parse_box(text)
        body = text[/\{\{WsBox(.*?)\n\}\}/m, 1] or return {}
        params = {}
        body.split(/\n\|/).each do |chunk|
          k, v = chunk.split("=", 2)
          next unless v
          params[k.strip.to_sym] = v.strip
        end
        params
      end

      # ---- Stamina (transposed "Coefficient" row) --------------------------
      # Header gives (series, size) per column; a single "Coefficient" row holds
      # the value per column.
      def stamina_rows(text, modifier, aura)
        tbl = text[/\{\|\s*class="wikitable"[^\n]*\n(.*?)\n\|\}/m, 1]
        return [] unless tbl && tbl.include?("Coefficient")

        rows_raw = split_rows(tbl)
        # series header: a row of cells each like "{{icon|X aura}} <Series>" spanning columns
        series_cols = expand_series_columns(rows_raw)
        size_cols   = expand_cells(find_row(rows_raw) { |r| r =~ /^!\s*(Small|Medium|Big|Massive|Ancestral|Unworldly)/ })
        coeff_cols  = expand_cells(find_row(rows_raw) { |r| r.include?("Coefficient") }, drop_first: true)

        out = []
        size_cols.each_with_index do |size_cell, i|
          size = normalize_size(size_cell) or next
          series = series_cols[i] or next
          coeff = parse_num(coeff_cols[i]) or next
          out << base_row(modifier, "stamina", series, size, aura).merge(
            formula_type: "stamina", coefficient: coeff
          )
        end
        out
      end

      # The series-header row uses colspans (cells without one span 1, e.g. the
      # single "Odious" column); expand into one series per column.
      def expand_series_columns(rows_raw)
        row = find_row(rows_raw) { |r| r =~ /aura\}\}/ } or return []
        cols = []
        cells = row.split("\n").flat_map { |ln| ln.start_with?("!") ? ln.sub(/^!/, "").split("!!") : [] }
        cells.each do |cell|
          next unless cell =~ /aura\}\}/ || cell =~ /\b(Normal|Omega|Odious|EX|Taboo)\b/i
          span = cell[/colspan="?(\d+)"?/, 1]&.to_i || 1
          label = cell.include?("|") ? cell.split("|", 2).last : cell
          series = self.class.series_for_title(label) or next
          span.times { cols << series }
        end
        cols
      end

      # ---- wsmod grids (flat / enmity / progression) -----------------------
      def grid_rows(text, modifier, aura)
        out = []
        text.scan(/\{\|\s*class="wikitable wsmod".*?\n\|\}/m).each do |tbl|
          rows_raw = split_rows(tbl)
          title = rows_raw.find { |r| r.include?("wsmod-title") } or next
          series = self.class.series_for_title(title) or next
          header = rows_raw.find { |r| r.include?("Skill Level") } or next
          sl_levels, has_max = parse_header(header)

          current_labels = nil
          rows_raw.each do |r|
            next unless r.include?("wsmod-tier") && !r.include?("Skill Level")
            size = row_size(r) or next
            labels = row_labels(r)
            current_labels = labels if labels.any?
            nums = row_values(r).map { |v| parse_num(v) }
            next if nums.empty?

            max = nil
            if has_max
              max = nums.last
              nums = nums[0...-1]
            end
            sl = sl_levels.zip(nums).to_h # {1=>v, 10=>v, ...}
            next if sl.values.all?(&:nil?) && max.nil?

            (current_labels || []).each do |label|
              boost = boost_key(label) or next
              formula = FORMULA_BY_BOOST.fetch(boost, "flat")
              out << base_row(modifier, boost, series, size, aura).merge(
                formula_type: formula,
                sl1: sl[1], sl10: sl[10], sl15: sl[15], sl20: sl[20], sl25: sl[25],
                max_value: max
              )
            end
          end
        end
        out
      end

      # ---- helpers ---------------------------------------------------------
      def base_row(modifier, boost, series, size, aura)
        { modifier: modifier, boost_type: boost, series: series, size: size,
          formula_type: "flat", sl1: nil, sl10: nil, sl15: nil, sl20: nil,
          sl25: nil, coefficient: nil, max_value: nil, aura_boostable: aura }
      end

      def split_rows(tbl)
        tbl.split(/\n\|-+/).map(&:strip)
      end

      def find_row(rows)
        rows.find { |r| yield r }
      end

      # SL column labels from the header row (drop Icon(s)/Skill Level cells).
      def parse_header(header)
        cells = header.split("\n").flat_map { |ln| ln.start_with?("!") ? ln.sub(/^!/, "").split("!!") : [] }
        labels = cells.map { |c| cell_content(c) }.reject(&:empty?)
        labels.reject! { |l| l =~ /\AIcons?\z/i || l =~ /Skill Level/i }
        has_max = labels.any? { |l| l =~ /Max/i }
        levels = labels.map { |l| l[/\d+/]&.to_i }.compact
        [levels, has_max]
      end

      def row_size(r)
        line = r.split("\n").find { |ln| ln.include?("wsmod-tier") && ln !~ /Skill Level/ }
        line && normalize_size(cell_content(line))
      end

      def row_labels(r)
        line = r.split("\n").find { |ln| ln.include?("wsmod-stat") } or return []
        line.scan(/\{\{Label\|([^}|]+)/).flatten.map(&:strip)
      end

      # All data (`|`) cells in a row, in order, cleaned.
      def row_values(r)
        vals = []
        r.split("\n").each do |ln|
          next unless ln.start_with?("|")
          next if ln.start_with?("|-") || ln.start_with?("|}")
          ln.sub(/^\|/, "").split("||").each { |c| vals << clean(c) }
        end
        vals
      end

      def boost_key(label)
        name = label.strip
        return @key_by_name[name] if @key_by_name[name]
        SERIES_PREFIXES.each do |p|
          if name.start_with?(p)
            base = name[p.length..]
            return @key_by_name[base] if @key_by_name[base]
          end
        end
        nil
      end

      def normalize_size(cell)
        s = cell_content(cell).downcase.strip
        SIZE_MAP[s]
      end

      # Strip MediaWiki cruft: attrs (`... | content`), refs, parser funcs,
      # comments, links, Label templates.
      def cell_content(cell)
        s = cell.dup
        s = s.split("\n").first.to_s
        # drop a leading "attrs |" segment if present (class=, colspan=, rowspan=, style=)
        s = s.sub(/\A[^|{}]*?(?:class|colspan|rowspan|style|scope)="[^|]*\|/, "")
        clean(s)
      end

      def clean(s)
        s = s.dup
        s.gsub!(/<ref[^>]*\/>/, "")
        s.gsub!(/<ref[^>]*>.*?<\/ref>/m, "")
        s.gsub!(/<!--.*?-->/m, "")
        s.gsub!(/\{\{\s*#[^{}]*\}\}/m, "") # parser functions {{ #ifeq:... }}
        s.gsub!(/\{\{Label\|([^}|]+)[^}]*\}\}/, '\1')
        s.gsub!(/\{\{verify\|([^}|]+)\}\}/, '\1')      # {{verify|0.4%}} → 0.4%
        s.gsub!(/\{\{crit\|2=([^}|]+)[^}]*\}\}/, '\1') # {{crit|2=15.0|3=50}} → 15.0
        s.gsub!(/\{\{[^{}]*\}\}/m, "")     # remaining templates
        s.gsub!(/\[\[(?:[^\]|]*\|)?([^\]]*)\]\]/, '\1') # [[a|b]] → b
        s.gsub!(/<[^>]+>/, "")
        s.gsub!(/rowspan="?\d+"?/, "")
        s.gsub!(/colspan="?\d+"?/, "")
        s.gsub!(/class="[^"]*"/, "")
        s.tr("|", " ")
        s.strip
      end

      def expand_cells(row, drop_first: false)
        return [] unless row
        cells = row.split("\n").flat_map do |ln|
          if ln.start_with?("!")
            ln.sub(/^!/, "").split("!!")
          elsif ln.start_with?("|") && !ln.start_with?("|-") && !ln.start_with?("|}")
            ln.sub(/^\|/, "").split("||")
          else
            []
          end
        end
        cells = cells.drop(1) if drop_first
        cells.map { |c| cell_content(c) }
      end

      def parse_num(s)
        return nil if s.nil?
        t = s.to_s.gsub(/[%,\s]/, "")
        return nil if t.empty? || t == "-"
        Float(t) rescue nil
      end
    end
  end
end
