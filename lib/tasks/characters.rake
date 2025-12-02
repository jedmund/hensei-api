# frozen_string_literal: true

require 'csv'

namespace :characters do
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
