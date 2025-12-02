# frozen_string_literal: true

require 'csv'

namespace :characters do
  # Known character lists for series detection
  ETERNALS = %w[Seofon Tweyen Threo Feower Fif Seox Niyon Eahta Tien Anre].freeze
  EVOKERS = %w[Maria\ Theresa Caim Lobelia Alanaan Fraux Katzelia Haaselia Nier Estarriola Geisenborger].freeze
  ZODIACS = %w[Anila Andira Mahira Vajra Kumbhira Vikala Catura Cidala].freeze

  # Infer season from name suffix
  def self.infer_season(name)
    return GranblueEnums::CHARACTER_SEASONS[:Valentine] if name.include?('(Valentine)')
    return GranblueEnums::CHARACTER_SEASONS[:Summer] if name.include?('(Summer)') || name.include?('(Yukata)')
    return GranblueEnums::CHARACTER_SEASONS[:Formal] if name.include?('(Formal)')
    return GranblueEnums::CHARACTER_SEASONS[:Halloween] if name.include?('(Halloween)')
    return GranblueEnums::CHARACTER_SEASONS[:Holiday] if name.include?('(Holiday)')

    nil # Standard characters have nil season
  end

  # Infer series from name and known lists
  def self.infer_series(name)
    series = []

    # Check name suffix patterns first
    if name.include?('(Grand)')
      series << GranblueEnums::CHARACTER_SERIES[:Grand]
    elsif name.include?('(Event)')
      series << GranblueEnums::CHARACTER_SERIES[:Event]
    elsif name.include?('(Promo)')
      series << GranblueEnums::CHARACTER_SERIES[:Promo]
    elsif name.include?('(Collab)')
      series << GranblueEnums::CHARACTER_SERIES[:Collab]
    end

    # Check seasonal series (can combine with above)
    series << GranblueEnums::CHARACTER_SERIES[:Summer] if name.include?('(Summer)')
    series << GranblueEnums::CHARACTER_SERIES[:Yukata] if name.include?('(Yukata)')
    series << GranblueEnums::CHARACTER_SERIES[:Valentine] if name.include?('(Valentine)')
    series << GranblueEnums::CHARACTER_SERIES[:Halloween] if name.include?('(Halloween)')
    series << GranblueEnums::CHARACTER_SERIES[:Formal] if name.include?('(Formal)')

    # Check known character lists (base name without suffix)
    base_name = name.gsub(/\s*\([^)]+\)/, '').strip

    if ETERNALS.any? { |e| base_name == e }
      series << GranblueEnums::CHARACTER_SERIES[:Eternal]
    end

    if EVOKERS.any? { |e| base_name == e }
      series << GranblueEnums::CHARACTER_SERIES[:Evoker]
    end

    if ZODIACS.any? { |z| base_name == z }
      series << GranblueEnums::CHARACTER_SERIES[:Zodiac]
    end

    # Default to Standard if no series detected and not a special type
    series << GranblueEnums::CHARACTER_SERIES[:Standard] if series.empty?

    series.uniq
  end

  # Infer gacha_available from series
  def self.infer_gacha_available(series)
    non_gachable = [
      GranblueEnums::CHARACTER_SERIES[:Eternal],
      GranblueEnums::CHARACTER_SERIES[:Evoker],
      GranblueEnums::CHARACTER_SERIES[:Event],
      GranblueEnums::CHARACTER_SERIES[:Collab],
      GranblueEnums::CHARACTER_SERIES[:Promo]
    ]

    # If any series is non-gachable, the character is not gachable
    (series & non_gachable).empty?
  end

  desc 'Auto-populate season/series from character names'
  task auto_populate: :environment do
    test_mode = ENV['TEST'] == 'true'
    updated = 0
    skipped = 0

    Character.find_each do |character|
      season = infer_season(character.name_en)
      series = infer_series(character.name_en)
      gacha_available = infer_gacha_available(series)

      if test_mode
        puts "#{character.name_en}:"
        puts "  season: #{season} (#{GranblueEnums::CHARACTER_SEASONS.key(season)})"
        puts "  series: #{series} (#{series.map { |s| GranblueEnums::CHARACTER_SERIES.key(s) }.join(', ')})"
        puts "  gacha_available: #{gacha_available}"
        updated += 1
      else
        if character.update(season: season, series: series, gacha_available: gacha_available)
          updated += 1
        else
          puts "Failed to update #{character.name_en}: #{character.errors.full_messages.join(', ')}"
        end
      end
    end

    puts "Updated: #{updated}, Skipped: #{skipped}"
    puts "(TEST MODE - no changes made)" if test_mode
  end
  desc 'Export characters to CSV for season/series mapping'
  task export_for_mapping: :environment do
    output_path = ENV['OUTPUT'] || Rails.root.join('export', 'characters_for_mapping.csv')
    FileUtils.mkdir_p(File.dirname(output_path))

    headers = %w[id granblue_id name_en name_jp rarity element season series gacha_available]

    CSV.open(output_path, 'w', headers: headers, write_headers: true) do |csv|
      Character.order(:id).find_each do |character|
        csv << [
          character.id,
          character.granblue_id,
          character.name_en,
          character.name_jp,
          character.rarity,
          character.element,
          character.season,
          character.series&.join(','),
          character.gacha_available
        ]
      end
    end

    count = Character.count
    puts "Exported #{count} characters to #{output_path}"
  end

  desc 'Import season/series data from curated CSV'
  task :import_season_series, [:csv_path] => :environment do |_t, args|
    csv_path = args[:csv_path]
    unless csv_path && File.exist?(csv_path)
      puts "Usage: bundle exec rake characters:import_season_series[path/to/curated.csv]"
      puts "Error: CSV file not found at #{csv_path}"
      exit 1
    end

    test_mode = ENV['TEST'] == 'true'
    updated = 0
    skipped = 0
    errors = []

    CSV.foreach(csv_path, headers: true) do |row|
      character = Character.find_by(id: row['id'])
      unless character
        errors << "Character not found with id: #{row['id']}"
        next
      end

      # Parse season (can be nil or integer)
      season = row['season'].presence&.to_i

      # Parse series (comma-separated integers or empty)
      series = row['series'].presence&.split(',')&.map(&:to_i) || []

      # Parse gacha_available (boolean)
      gacha_available = row['gacha_available']&.downcase
      gacha_available = case gacha_available
                        when 'true', '1', 't' then true
                        when 'false', '0', 'f' then false
                        else true # default
                        end

      if test_mode
        puts "Would update #{character.name_en}: season=#{season}, series=#{series}, gacha_available=#{gacha_available}"
        updated += 1
      else
        if character.update(season: season, series: series, gacha_available: gacha_available)
          updated += 1
        else
          errors << "Failed to update #{character.name_en} (#{character.id}): #{character.errors.full_messages.join(', ')}"
        end
      end
    end

    puts "Updated: #{updated}, Skipped: #{skipped}, Errors: #{errors.count}"
    errors.each { |e| puts "  - #{e}" } if errors.any?
    puts "(TEST MODE - no changes made)" if test_mode
  end
end
