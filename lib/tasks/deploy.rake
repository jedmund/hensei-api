# frozen_string_literal: true

require_relative '../post_deployment/manager'
require_relative '../logging_helper'

namespace :deploy do
  desc 'Populate all new gacha categorization fields (promotions, season, series). Options: OVERWRITE=true to refresh all'
  task populate_gacha_fields: :environment do
    puts '=' * 60
    puts 'Populating gacha categorization fields from wiki_raw'
    puts '=' * 60
    puts

    # Step 1: Migrate gacha table to promotions arrays (existing data)
    puts 'Step 1: Migrating gacha table to promotions arrays...'
    Rake::Task['gacha:migrate_promotions'].invoke
    puts

    # Step 2: Parse weapons from wiki_raw to fill any gaps
    puts 'Step 2: Parsing weapons from wiki_raw...'
    Rake::Task['deploy:parse_weapons'].invoke
    puts

    # Step 3: Parse summons from wiki_raw to fill any gaps
    puts 'Step 3: Parsing summons from wiki_raw...'
    Rake::Task['deploy:parse_summons'].invoke
    puts

    # Step 4: Parse characters from wiki_raw for season/series/gacha_available
    puts 'Step 4: Parsing characters from wiki_raw...'
    Rake::Task['deploy:parse_characters'].invoke
    puts

    puts '=' * 60
    puts 'Done!'
    puts '=' * 60
  end

  desc 'Parse weapons from wiki_raw to populate promotions. Options: OVERWRITE=true'
  task parse_weapons: :environment do
    overwrite = ENV['OVERWRITE'] == 'true'

    weapons = Weapon.where.not(wiki_raw: [nil, ''])
    weapons = weapons.where(promotions: []) unless overwrite

    total = weapons.count
    updated = 0
    skipped = 0
    puts "  Found #{total} weapons to process#{overwrite ? ' (overwrite mode)' : ''}"

    weapons.find_each.with_index do |weapon, index|
      print "\r  Processing #{index + 1}/#{total}: #{weapon.name_en.to_s.truncate(40)}".ljust(80)

      obtain = extract_wiki_field(weapon.wiki_raw, 'obtain')
      if obtain.blank?
        skipped += 1
        next
      end

      promotions = promotions_from_obtain(obtain)
      if promotions.present?
        weapon.update_column(:promotions, promotions)
        updated += 1
      end
    end

    puts
    puts "  Updated: #{updated}, Skipped (no obtain): #{skipped}"
  end

  desc 'Parse summons from wiki_raw to populate promotions. Options: OVERWRITE=true'
  task parse_summons: :environment do
    overwrite = ENV['OVERWRITE'] == 'true'

    summons = Summon.where.not(wiki_raw: [nil, ''])
    summons = summons.where(promotions: []) unless overwrite

    total = summons.count
    updated = 0
    skipped = 0
    puts "  Found #{total} summons to process#{overwrite ? ' (overwrite mode)' : ''}"

    summons.find_each.with_index do |summon, index|
      print "\r  Processing #{index + 1}/#{total}: #{summon.name_en.to_s.truncate(40)}".ljust(80)

      obtain = extract_wiki_field(summon.wiki_raw, 'obtain')
      if obtain.blank?
        skipped += 1
        next
      end

      promotions = promotions_from_obtain(obtain)
      if promotions.present?
        summon.update_column(:promotions, promotions)
        updated += 1
      end
    end

    puts
    puts "  Updated: #{updated}, Skipped (no obtain): #{skipped}"
  end

  desc 'Parse characters from wiki_raw to populate season/series/gacha_available. Options: OVERWRITE=true'
  task parse_characters: :environment do
    overwrite = ENV['OVERWRITE'] == 'true'

    characters = Character.where.not(wiki_raw: [nil, ''])
    characters = characters.where(series: [], season: nil) unless overwrite

    total = characters.count
    updated = 0
    skipped = 0
    puts "  Found #{total} characters to process#{overwrite ? ' (overwrite mode)' : ''}"

    characters.find_each.with_index do |character, index|
      print "\r  Processing #{index + 1}/#{total}: #{character.name_en.to_s.truncate(40)}".ljust(80)

      wiki_series = extract_wiki_field(character.wiki_raw, 'series')
      obtain = extract_wiki_field(character.wiki_raw, 'obtain')

      series = series_from_wiki(wiki_series, obtain, character.wiki_en)
      season = season_from_wiki(obtain, character.wiki_en)
      gacha_available = gacha_available_from_wiki(wiki_series, obtain)

      if series.present? || season.present?
        character.update_columns(
          series: series,
          season: season,
          gacha_available: gacha_available
        )
        updated += 1
      else
        skipped += 1
      end
    end

    puts
    puts "  Updated: #{updated}, Skipped (no data): #{skipped}"
  end

  # Helper methods for parsing wiki_raw

  def extract_wiki_field(wiki_raw, field)
    return nil if wiki_raw.blank?

    wiki_raw.each_line do |line|
      if line.start_with?("|#{field}=")
        return line.sub("|#{field}=", '').strip
      end
    end
    nil
  end

  def promotions_from_obtain(obtain)
    return [] if obtain.blank?

    mapping = Granblue::Parsers::Wiki.promotions
    obtain.downcase.split(',').map(&:strip).filter_map do |value|
      mapping[value]
    end.uniq.sort
  end

  def series_from_wiki(wiki_series, obtain, wiki_en)
    series = []
    wiki_en = wiki_en.to_s.downcase

    # Primary series from |series= field
    primary = Granblue::Parsers::Wiki.character_series[wiki_series.to_s.downcase.strip]
    series << primary if primary

    # Additional from obtain
    obtain = obtain.to_s.downcase
    series << 2 if obtain.include?('grand') && !series.include?(2)
    series << 3 if obtain.include?('zodiac') && !series.include?(3)

    # Seasonal from page name
    series << 10 if (wiki_en.include?('summer') || wiki_en.include?('swimsuit')) && !series.include?(10)
    series << 11 if wiki_en.include?('yukata') && !series.include?(11)
    series << 12 if wiki_en.include?('valentine') && !series.include?(12)
    series << 13 if wiki_en.include?('halloween') && !series.include?(13)
    series << 14 if wiki_en.include?('formal') && !series.include?(14)

    series.uniq.sort
  end

  def season_from_wiki(obtain, wiki_en)
    wiki_en = wiki_en.to_s.downcase
    obtain = obtain.to_s.downcase

    return 2 if wiki_en.include?('valentine') || obtain.include?('valentine')
    return 3 if wiki_en.include?('formal') || obtain.include?('formal')
    return 4 if wiki_en.include?('summer') || wiki_en.include?('yukata') || obtain.include?('summer')
    return 5 if wiki_en.include?('halloween') || obtain.include?('halloween')
    return 6 if wiki_en.include?('holiday') || obtain.include?('holiday')

    # Standard for gacha characters
    1 if obtain.present? && (obtain.include?('premium') || obtain.include?('flash') || obtain.include?('legend'))
  end

  def gacha_available_from_wiki(wiki_series, obtain)
    wiki_series = wiki_series.to_s.downcase.strip
    obtain = obtain.to_s.downcase

    # Non-gacha series
    return false if %w[eternal evoker archangel event promo collab].include?(wiki_series)

    # Check obtain for gacha indicators
    %w[premium flash legend classic grand zodiac valentine summer halloween holiday formal].any? { |g| obtain.include?(g) }
  end

  desc 'Post-deployment tasks: Run migrations, import data, download images, and rebuild search indices. Options: TEST=true for test mode, VERBOSE=true for verbose output, STORAGE=local|s3|both'
  task post_deployment: :environment do
    include LoggingHelper

    # Load all required files
    Dir[Rails.root.join('lib', 'post_deployment', '**', '*.rb')].each { |file| require file }
    Dir[Rails.root.join('lib', 'granblue', '**', '*.rb')].each { |file| require file }

    # Ensure Rails environment is loaded
    Rails.application.eager_load!

    begin
      display_startup_banner

      options = parse_and_validate_options
      display_configuration(options)

      # Execute the deployment tasks
      manager = PostDeployment::Manager.new(options)
      manager.run

    rescue StandardError => e
      display_error(e)
      exit 1
    end
  end

  private

  def display_startup_banner
    puts "Starting deployment process...\n"
  end

  def parse_and_validate_options
    storage = parse_storage_option

    {
      test_mode: ENV['TEST'] == 'true',
      verbose: ENV['VERBOSE'] == 'true',
      storage: storage,
      force: ENV['FORCE'] == 'true'
    }
  end

  def parse_storage_option
    storage = (ENV['STORAGE'] || 'both').to_sym

    unless [:local, :s3, :both].include?(storage)
      raise ArgumentError, 'Invalid STORAGE option. Must be one of: local, s3, both'
    end

    storage
  end

  def display_configuration(options)
    log_header('Configuration', '-')
    puts "\n"
    display_status("Test mode", options[:test_mode])
    display_status("Verbose output", options[:verbose])
    display_status("Process all", options[:force])
    puts "Storage mode:\t#{options[:storage]}"
    puts "\n"
  end

  def display_status(label, enabled)
    status = enabled ? "✅ Enabled" : "❌ Disabled"
    puts "#{label}:\t#{status}"
  end

  def display_error(error)
    puts "\n❌ Error during deployment:"
    puts "  #{error.class}: #{error.message}"
    puts "\nStack trace:" if ENV['VERBOSE'] == 'true'
    puts error.backtrace.take(10) if ENV['VERBOSE'] == 'true'
    puts "\nDeployment failed! Please check the logs for details."
  end
end
