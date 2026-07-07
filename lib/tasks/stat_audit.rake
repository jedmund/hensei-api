# frozen_string_literal: true

require 'nokogiri'

# ===========================================================================
# JP wiki stat parser (gbf-wiki.com HTML)
#
# The stat table has header rows containing <strong>MinHP</strong>,
# <strong>MaxHP</strong>, <strong>MinATK</strong>, <strong>MaxATK</strong>.
# The row immediately after each header row holds the corresponding values.
# Max values may appear as "1500 / 1877" (base / FLB).
# ===========================================================================
module Granblue
  module StatAudit
    module JpWikiStatParser
      module_function

      def parse(html)
        doc = Nokogiri::HTML(html)
        rows = doc.css('div#body table.style_table tr').to_a
        stats = {}

        rows.each_with_index do |row, index|
          text = row.text

          if text.include?('MinHP')
            merge_stat(stats, :min_hp, :max_hp, :max_hp_flb, row_values(rows[index + 1]))
          end

          if text.include?('MinATK')
            merge_stat(stats, :min_atk, :max_atk, :max_atk_flb, row_values(rows[index + 1]))
          end
        end

        stats
      end

      # Extract numeric values from a data row.
      # Returns [min_value, max_base, max_flb] where max_flb may be nil.
      def row_values(row)
        return [] unless row

        cells = row.css('td').map { |td| td.text.strip }

        # Min value is the second-to-last cell; max value is the last cell.
        min_text = cells[-2].to_s
        max_text = cells[-1].to_s

        min_val = min_text[/\A(\d+)\z/, 1]&.to_i
        max_base = max_text[%r{\A(\d+)\s*/\s*(\d+)}, 1]&.to_i || max_text[/\A(\d+)\z/, 1]&.to_i
        max_flb = max_text[%r{\A\d+\s*/\s*(\d+)}, 1]&.to_i

        [min_val, max_base, max_flb]
      end

      def merge_stat(stats, min_key, max_key, flb_key, values)
        return if values.empty?

        stats[min_key] = values[0] if values[0]&.positive?
        stats[max_key] = values[1] if values[1]&.positive?
        stats[flb_key] = values[2] if values[2]&.positive?
      end
    end

    # =========================================================================
    # Repopulation logic
    # =========================================================================

    class StatFixer
      STAT_COLUMNS = %i[min_hp max_hp max_hp_flb min_atk max_atk max_atk_flb].freeze

      attr_reader :source

      def initialize(source:)
        @source = source
      end

      # @return [Hash] patch with :action, :source, and any changed columns
      def fix(record, model)
        parsed = source == 'jp' ? parse_jp(record, model) : parse_en(record, model)
        return { action: 'SKIP (no wiki data)', source: source } if parsed.nil?
        return { action: 'SKIP (parse failed)', source: source } if parsed.empty?

        updates = diff(record, parsed)
        return { action: 'OK (already matches)', source: source } if updates.empty?

        apply_updates(record, updates)
        # Use string keys so they don't clobber the symbol keys holding the
        # original values in the entry hash — the reporter checks for the
        # string key to render an "old->new" diff.
        { action: 'UPDATED', source: source }.merge(
          updates.transform_keys(&:to_s).transform_values(&:last)
        )
      end

      private

      def diff(record, parsed)
        updates = {}
        STAT_COLUMNS.each do |col|
          next unless parsed.key?(col)

          new_val = parsed[col]
          old_val = record.public_send(col)
          next if new_val.to_i == old_val.to_i

          updates[col] = [old_val, new_val.to_i]
        end
        updates
      end

      def apply_updates(record, updates)
        updates.each do |col, pair|
          record.public_send(:"#{col}=", pair.last)
        end
        record.save!(validate: false)
      rescue ActiveRecord::RecordInvalid => e
        warn "  Save failed for #{record.class} #{record.granblue_id}: #{e.message}"
      end

      # --- EN wiki: parse wiki_raw template text via WikiDataParser ---

      def parse_en(record, _model)
        return nil if record.wiki_raw.blank?

        case record
        when Character then Granblue::Parsers::WikiDataParser.parse_character(record.wiki_raw)
        when Weapon    then Granblue::Parsers::WikiDataParser.parse_weapon(record.wiki_raw)
        when Summon    then Granblue::Parsers::WikiDataParser.parse_summon(record.wiki_raw)
        end
      end

      # --- JP wiki: parse wiki_raw_jp HTML (characters & summons only) ---

      def parse_jp(record, model)
        html = record.wiki_raw_jp
        return nil if html.blank?

        return {} unless [Character, Summon].include?(model)

        JpWikiStatParser.parse(html)
      end
    end

    # =========================================================================
    # Report rendering
    # =========================================================================

    class StatReporter
      HEADERS = %w[Type Name GranblueID min_hp min_atk max_hp max_atk Match Wiki Action].freeze

      attr_reader :coverage

      def initialize
        @sections = Hash.new { |h, k| h[k] = [] }
        @coverage = Hash.new { |h, k| h[k] = { total: 0, en: 0, jp: 0, jp_title: 0 } }
      end

      def add_section(name)
        @sections[name] ||= []
      end

      def add_entry(section, entry)
        @sections[section] << entry

        cov = @coverage[section]
        cov[:total] += 1
        cov[:en] += 1 if entry[:has_en_raw]
        cov[:jp] += 1 if entry[:has_jp_raw]
        cov[:jp_title] += 1 if entry[:has_ja_title]
      end

      def total_count
        @sections.values.sum(&:size)
      end

      def print(export: false)
        if total_count.zero?
          puts 'No suspicious records found (min_hp==min_atk or max_hp==max_atk).'
          return
        end

        puts "Found #{total_count} suspicious record(s):\n\n"

        lines = render_table
        lines.concat(render_coverage)

        return unless export

        dir = Rails.root.join('export')
        path = dir.join('stat-audit-report.txt')
        FileUtils.mkdir_p(dir)
        File.write(path, "#{lines.join("\n")}\n")
        puts "Report written to #{path}"
      end

      private

      def render_table
        lines = []

        @sections.each do |section, entries|
          next if entries.empty?

          rows = entries.map { |e| format_row(e) }
          widths = compute_widths(rows)

          border = "+#{HEADERS.map { |h| '-' * (widths[h] + 2) }.join('+')}+"

          lines << ''
          lines << "#{section} (#{entries.size})"
          lines << border
          lines << format_header_row(widths)
          lines << border
          rows.each { |r| lines << format_data_row(r, widths) }
          lines << border
          lines << ''
        end

        puts lines.join("\n")
        lines
      end

      def render_coverage
        lines = ['', 'Wiki data coverage for suspicious records:']
        @coverage.each do |section, cov|
          next if cov[:total].zero?

          jp_col = jp_column_name(section)
          lines << "  #{section} (#{cov[:total]}): " \
                   "EN wiki #{cov[:en]}/#{cov[:total]}, " \
                   "#{jp_col} #{cov[:jp]}/#{cov[:total]} " \
                   "(#{cov[:jp_title]} have JP page title)"
        end

        actionable = actionable_hints
        lines.concat(actionable) if actionable.any?

        puts lines.join("\n")
        lines
      end

      def actionable_hints
        hints = ['']
        @coverage.each do |section, cov|
          model = section.downcase
          if cov[:jp] < cov[:total] && model != 'weapon'
            missing = cov[:total] - cov[:jp]
            hints << "  #{missing} #{model}s missing JP wiki HTML — run: " \
                     "rake granblue:download_jp_wiki model=#{model}"
          end
          next unless cov[:en] < cov[:total]

          missing = cov[:total] - cov[:en]
          hints << "  #{missing} #{model}s missing EN wiki text — run: " \
                   "rake granblue:fetch_wiki_data type=#{model.capitalize}"
        end
        hints
      end

      def jp_column_name(section)
        section == 'Weapon' ? 'JP(n/a)' : 'JP wiki'
      end

      def format_row(entry)
        {
          'Type'       => entry[:model],
          'Name'       => entry[:name].to_s.slice(0, 40),
          'GranblueID' => entry[:granblue_id].to_s,
          'min_hp'     => format_change(entry, :min_hp),
          'min_atk'    => format_change(entry, :min_atk),
          'max_hp'     => format_change(entry, :max_hp),
          'max_atk'    => format_change(entry, :max_atk),
          'Match'      => entry[:matches],
          'Wiki'       => format_wiki_status(entry),
          'Action'     => entry[:action].to_s
        }
      end

      def format_wiki_status(entry)
        en = entry[:has_en_raw] ? 'Y' : 'N'
        jp = if entry[:jp_column]
               entry[:has_jp_raw] ? 'Y' : 'N'
             else
               '-'
             end
        "EN#{en} JP#{jp}"
      end

      # Shows "old -> new" when a value was changed, otherwise just the value.
      def format_change(entry, key)
        str_key = key.to_s
        old = entry[key]

        if entry.key?(str_key)
          "#{old}->#{entry[str_key]}"
        else
          old.to_s
        end
      end

      def compute_widths(rows)
        widths = {}
        HEADERS.each do |h|
          widths[h] = [h.length, *rows.map { |r| r[h].length }].max
        end
        widths
      end

      def format_header_row(widths)
        cells = HEADERS.map { |h| " #{h.ljust(widths[h])}" }
        "|#{cells.join('|')}|"
      end

      def format_data_row(row, widths)
        cells = HEADERS.map { |h| " #{row[h].ljust(widths[h])}" }
        "|#{cells.join('|')}|"
      end
    end
  end
end

# ===========================================================================
# Rake task
# ===========================================================================

namespace :granblue do
  desc <<~DESC
    Find characters, weapons, and summons where min_hp == min_atk or
    max_hp == max_atk (likely bad/placeholder data), and optionally
    repopulate the stat columns from stored wiki data.

    The EN wiki source parses wiki_raw (gbf.wiki template text) via
    WikiDataParser. The JP wiki source parses wiki_raw_jp (gbf-wiki.com
    HTML); it is only available on characters and summons.

    Usage:
      rake granblue:audit_stats                              # Scan all types, report only
      rake granblue:audit_stats type=character               # Scan one type
      rake granblue:audit_stats type=weapon                  #   character | weapon | summon
      rake granblue:audit_stats repopulate=true              # Fix values from EN wiki (default)
      rake granblue:audit_stats repopulate=true source=jp    # Fix values from JP wiki
      rake granblue:audit_stats export=true                  # Also write report to export/
  DESC
  task audit_stats: :environment do
    type       = ENV['type'].presence || 'all'
    repopulate = ENV['repopulate'] == 'true'
    source     = ENV['source'].presence || 'en'
    export     = ENV['export'] == 'true'

    valid_types = %w[all character weapon summon]
    unless valid_types.include?(type)
      warn "Invalid type '#{type}'. Must be one of: #{valid_types.join(', ')}"
      exit 1
    end

    unless %w[en jp].include?(source)
      warn "Invalid source '#{source}'. Must be 'en' or 'jp'."
      exit 1
    end

    models = case type
             when 'all'       then [Character, Weapon, Summon]
             when 'character' then [Character]
             when 'weapon'    then [Weapon]
             when 'summon'    then [Summon]
             end

    reporter = Granblue::StatAudit::StatReporter.new
    fixer    = Granblue::StatAudit::StatFixer.new(source: source)

    models.each do |model|
      reporter.add_section(model.name)

      suspicious_scope(model).find_each do |record|
        matches = detect_matches(record)
        next if matches.empty?

        entry = build_entry(model.name, record, matches)
        reporter.add_entry(model.name, entry)

        next unless repopulate

        entry.merge!(fixer.fix(record, model))
      end
    end

    reporter.print(export: export)
  end

  desc <<~DESC
    Report wiki data coverage (wiki_raw / wiki_raw_jp / wiki_ja) for all
    characters, weapons, and summons. Helps identify which records need
    wiki data fetched before audit_stats repopulation can work.

    Usage:
      rake granblue:wiki_coverage                    # All types
      rake granblue:wiki_coverage type=character     # One type
  DESC
  task wiki_coverage: :environment do
    type = ENV['type'].presence || 'all'

    models = case type
             when 'all'       then [Character, Weapon, Summon]
             when 'character' then [Character]
             when 'weapon'    then [Weapon]
             when 'summon'    then [Summon]
             end

    puts 'Wiki data coverage report'
    puts '=' * 60

    models.each do |model|
      total      = model.count
      has_en_raw = model.where.not(wiki_raw: [nil, '']).count
      has_ja     = model.where.not(wiki_ja: [nil, '']).count
      has_jp_raw = model.column_names.include?('wiki_raw_jp') ? model.where.not(wiki_raw_jp: [nil, '']).count : nil

      jp_display = has_jp_raw.nil? ? 'n/a' : "#{has_jp_raw}/#{total}"

      puts ""
      puts "#{model.name} (#{total} total):"
      puts "  wiki_raw  (EN template text): #{has_en_raw}/#{total}" \
           "#{'  <-- MISSING' if has_en_raw < total}"
      puts "  wiki_ja   (JP page title):    #{has_ja}/#{total}" \
           "#{'  <-- MISSING' if has_ja < total}"
      puts "  wiki_raw_jp (JP HTML):        #{jp_display}" \
           "#{has_jp_raw && has_jp_raw < total ? '  <-- MISSING' : ''}"

      next unless has_jp_raw && has_jp_raw < total && has_ja.positive?

      puts ""
      puts "  To fetch missing JP wiki HTML for #{has_ja - has_jp_raw} records:"
      puts "    rake granblue:download_jp_wiki model=#{model.name.downcase}"
    end
  end

  # ---------------------------------------------------------------------------

  # Scope that catches both conditions (min_hp==min_atk OR max_hp==max_atk).
  # Zero values are excluded — they indicate unpopulated rows, not corruption.
  def suspicious_scope(model)
    model
      .where('min_hp IS NOT NULL AND min_atk IS NOT NULL AND min_hp = min_atk AND min_hp > 0')
      .or(model.where('max_hp IS NOT NULL AND max_atk IS NOT NULL AND max_hp = max_atk AND max_hp > 0'))
  end

  # Returns [:min, :max, [] — which conditions matched for this record.
  def detect_matches(record)
    matches = []
    if record.min_hp.present? && record.min_atk.present? &&
       record.min_hp.positive? && record.min_hp == record.min_atk
      matches << :min
    end
    if record.max_hp.present? && record.max_atk.present? &&
       record.max_hp.positive? && record.max_hp == record.max_atk
      matches << :max
    end
    matches
  end

  def build_entry(model_name, record, matches)
    {
      model:        model_name,
      name:         record.name_en.presence || record.name_jp.presence || '(unnamed)',
      granblue_id:  record.granblue_id,
      min_hp:       record.min_hp,
      min_atk:      record.min_atk,
      max_hp:       record.max_hp,
      max_atk:      record.max_atk,
      matches:      matches.map(&:to_s).join('+'),
      action:       '—',
      has_en_raw:   record.wiki_raw.present?,
      has_jp_raw:   record.respond_to?(:wiki_raw_jp) && record.wiki_raw_jp.present?,
      has_ja_title: record.respond_to?(:wiki_ja) && record.wiki_ja.present?,
      jp_column:    record.respond_to?(:wiki_raw_jp)
    }
  end
end
