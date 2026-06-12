# frozen_string_literal: true

require 'nokogiri'

module Granblue
  module Parsers
    # Parses Japanese skill text out of a cached gbf-wiki.com page (wiki_raw_jp).
    # The page is PukiWiki HTML; skill data lives in <table class="style_table">
    # rows under 奥義 / アビリティ / サポート section headers. Returns a flat,
    # ordered structure aligned positionally to the in-game ability slots, which
    # the EN-built graph joins onto by position.
    class JpWikiSkillParser
      # A cell is a section header when it introduces one of these sections.
      OUGI_HEADER = /奥義/
      ABILITY_COLS = /使用間隔/ # only the ability table has 使用間隔
      SKILL_LEVEL_COL = /習得Lv/
      STOP_MARKERS = /フレーバーテキスト|加入方法|上限解放素材|リミットボーナス/

      def initialize(record)
        @record = record
      end

      def parse
        body = document&.at_css('div#body')
        return empty_result if body.nil?

        ougi = []
        abilities = []
        support = []
        section = nil

        skill_rows(body).each do |cells, images|
          case row_kind(cells)
          when :ougi_header then section = :ougi
          when :ability_header then section = :ability
          when :support_header then section = :support
          when :stop then section = nil
          when :data
            next if section.nil? || cells.first.blank?

            case section
            when :ougi then ougi << ougi_entry(cells)
            # 1-cell ability rows are option sub-skills with name+effect merged
            # into a single cell (no clean split) — skip rather than emit garbage.
            when :ability then abilities << ability_entry(cells, images) if cells.size >= 2
            when :support then support << support_entry(cells)
            end
          end
        end

        { ougi: ougi, abilities: abilities, support: support }
      end

      private

      def document
        return @document if defined?(@document)

        @document = @record.wiki_raw_jp.present? ? Nokogiri::HTML(@record.wiki_raw_jp) : nil
      end

      # Rows from every style_table in the body, as [cell_texts, image_alts],
      # with tooltip <script> noise stripped.
      def skill_rows(body)
        body.css('table.style_table tr').map do |tr|
          cells = tr.css('th,td').map { |cell| clean_cell(cell) }
          images = tr.css('img').filter_map { |img| img['alt'] }
          [cells, images]
        end
      end

      def clean_cell(cell)
        cell = cell.dup
        cell.css('script').remove
        cell.text.gsub(/\s+/, ' ').strip
      end

      def row_kind(cells)
        joined = cells.join
        return :stop if joined.match?(STOP_MARKERS)
        return :ability_header if header?(cells, /アビリティ/) || (joined.match?(ABILITY_COLS) && joined.match?(SKILL_LEVEL_COL))
        return :support_header if header?(cells, /サポート/) || (joined.match?(SKILL_LEVEL_COL) && joined.exclude?('使用間隔'))
        return :ougi_header if header?(cells, OUGI_HEADER)

        :data
      end

      # A section header row leads with the section label and carries the 名称
      # column. Handles both one-row (奥義|名称|効果) and two-row (th 奥義 / 名称|…)
      # table layouts.
      def header?(cells, pattern)
        cells.first&.match?(pattern) && cells.include?('名称')
      end

      def ougi_entry(cells)
        { name_jp: cells.first, effect_jp: cells.last }
      end

      # Ability rows are 6 cells when full (name, 習得Lv, +Lv, 使用間隔, 効果時間,
      # 効果); transform/continuation rows have fewer (rowspan drops leading cells).
      def ability_entry(cells, images)
        entry = { name_jp: cells.first, effect_jp: cells.last, image_id: skill_image_id(images) }
        if cells.size >= 6
          entry[:unlock_level] = level_value(cells[1])
          entry[:enhance_levels] = enhance_levels(cells[2])
          entry[:cooldown] = cooldown_value(cells[3])
        end
        entry
      end

      def support_entry(cells)
        entry = { name_jp: cells.first, effect_jp: cells.last }
        if cells.size >= 4
          entry[:unlock_level] = level_value(cells[1])
          entry[:enhance_levels] = enhance_levels(cells[2])
        end
        entry
      end

      def skill_image_id(images)
        images.map { |alt| alt[/\A(\d+_\d+)\.png\z/, 1] }.compact.first
      end

      def level_value(text)
        return if text.blank? || text.include?('初期')

        text[/Lv(\d+)/, 1]&.to_i
      end

      def enhance_levels(text)
        text.to_s.scan(/Lv(\d+)/).flatten.map(&:to_i)
      end

      def cooldown_value(text)
        text[/(\d+)ターン/, 1]&.to_i
      end

      def empty_result
        { ougi: [], abilities: [], support: [] }
      end
    end
  end
end
