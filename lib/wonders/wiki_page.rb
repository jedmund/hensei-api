# frozen_string_literal: true

module Wonders
  ##
  # Reads the gbf.wiki "Wonders" page (wikitext): one entry per Wonder, in
  # page order, with the game category its section maps to. Used by
  # SeedGenerator, which treats the page as the master list.
  class WikiPage
    # Wiki section heading => game category_id
    SECTION_CATEGORIES = {
      'Girl in Blue' => '1',
      'Dawning Sky' => '2',
      'Wayfaring Astral' => '3',
      'Crucible Seal' => '4',
      'Other' => '5',
      'Cardinal Saint Yupei and Longxin' => '6',
      'Arcarum Evoker Rings of Fate' => '8'
    }.freeze

    def initialize(wikitext)
      @wikitext = wikitext
    end

    # Wiki markup to plain text with newlines
    def self.sanitize(text)
      plain = text.to_s.gsub(%r{<(?:br|hr)\s*/?>}i, "\n").gsub(/<[^>]*>/, '')
      plain = plain.gsub(/\[\[(?:File|Image):[^\]]*\]\]/i, '')
                   .gsub(/\[\[([^\]|]*\|)?([^\]]*)\]\]/) { Regexp.last_match(2) }
                   .gsub(/\{\{(?:itm|atkmod)\|([^|}]*)[^}]*\}\}/i) { Regexp.last_match(1) }
                   .gsub(/\{\{[^}]*\}\}/, '')
                   .gsub(/'{2,}/, '').gsub('&nbsp;', ' ')
      plain.lines.map { |line| line.sub(/\A\*\s*/, '').strip }.reject(&:empty?).join("\n")
    end

    # Wiki rows, in page order: { name:, category:, position:, description:,
    # effect_lines:, no_stack: }
    def entries
      @entries ||= begin
        positions = Hash.new(0)
        rows.filter_map do |section, cells|
          category = SECTION_CATEGORIES[section]
          next unless category

          name = SeedGenerator.normalize_name(cells[1])
          next if name.empty?

          effect = cells[3].to_s
          {
            name: name,
            category: category,
            position: positions[category] += 1,
            description: self.class.sanitize(cells[2]),
            effect_lines: self.class.sanitize(effect).lines.map(&:strip).grep_v(/does not stack/i),
            no_stack: effect[/does not stack with \{\{itm\|(.+?) \(SSR\)\}\}/i, 1]
          }
        end
      end
    end

    # [[section heading, [cell, …]], …] for each wikitable row
    private

    def rows
      rows = []
      section = nil
      cells = nil
      @wikitext.each_line do |raw|
        line = raw.chomp
        if (heading = line[/\A=+\s*(.+?)\s*=+\z/, 1])
          section = heading
        elsif line.start_with?('|-', '|}')
          rows << [section, cells] if cells&.any?
          cells = line.start_with?('|-') ? [] : nil
        elsif cells && line.start_with?('|')
          cells << line[1..]
        elsif cells&.any?
          cells[-1] = "#{cells[-1]}\n#{line}"
        end
      end
      rows
    end
  end
end
