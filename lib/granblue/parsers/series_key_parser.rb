# frozen_string_literal: true

module Granblue
  module Parsers
    # Parses a weapon-series summary page (e.g. Dark_Opus_Weapons, Destroyer_Weapons) into the
    # series' key→skill mapping: each Pendulum / Teluma / Anklet / Chain item paired with its
    # skill prose. The mapping is element-agnostic (the wiki writes "[Element]" / "weapon element"),
    # so it is parsed once per series and applies to every element. Pure parsing — no fetch, no DB.
    class SeriesKeyParser
      # A key table's header names a key-type column AND a "Skill" column.
      KEY_TABLE_HEADER = /\b(Pendulum|Teluma|Anklet|Chain)\b.*?Skill/im

      # → [{ name: <key item name>, skill_text: <the "Skill:" prose> }]
      def self.parse(wikitext)
        wikitext.to_s.scan(/\{\|.*?\|\}/m)
                .select { |table| table[/\A\{\|.*?\n(.*)/m, 1].to_s =~ KEY_TABLE_HEADER }
                .flat_map { |table| rows(table) }
      end

      def self.rows(table)
        table.split(/\|-/).filter_map do |row|
          name = row[/\{\{\s*itm\s*\|\s*([^|}]+?)\s*[|}]/, 1] or next
          skill = skill_text(row) or next

          { name: name.strip, skill_text: skill }
        end
      end

      # The "Skill:" clause of a row, up to the charge-attack effect / level-up note / row end.
      def self.skill_text(row)
        text = clean(row)
        text[/Skill:\s*(.+?)\s*(?:Charge Attack|Upgraded at level|Trade Materials|\z)/i, 1].presence
      end

      def self.clean(str)
        str.gsub(/\{\{\s*itm\s*\|\s*([^|}]+)[^}]*\}\}/, '\1') # {{itm|Name|…}} → Name
           .gsub(%r{<ref[^>]*/>}, "")          # self-closing <ref …/> first, so the next
           .gsub(%r{<ref[^>]*>.*?</ref>}m, "") # paired <ref>…</ref> can't span across it
           .gsub(/\{\{[^{}]*\}\}/, "")
           .gsub(/\[\[[^\]|]*\|?([^\]]*)\]\]/, '\1')
           .gsub(/<[^>]+>/, "")
           .gsub(/'''|''/, "")
           .gsub(/\s+/, " ").strip
      end

      private_class_method :rows, :skill_text, :clean
    end
  end
end
