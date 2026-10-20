namespace :granblue do
  desc <<~DESC
    Fetch and store raw wiki data (wiki_raw) for Characters, Weapons or Summons.
    One gbf.wiki request per row, at least 2s apart (Granblue::WikiThrottle).

    Usage:
      rake granblue:fetch_wiki_data                         # all Characters without wiki_raw (default)
      rake granblue:fetch_wiki_data type=Weapon             # Weapons (or Summon)
      rake granblue:fetch_wiki_data id=3040252000           # one granblue_id (both style rows)
      rake granblue:fetch_wiki_data ids=3040252000,3040164000
      rake granblue:fetch_wiki_data rarity=3                # SSR only; rarity=1,2 for R and SR
      rake granblue:fetch_wiki_data force=true              # also refetch rows that have wiki_raw
      rake granblue:fetch_wiki_data delay=3.0               # seconds between requests (default and minimum 2.0)
      rake granblue:fetch_wiki_data changed_out=tmp/changed.txt  # write the changed granblue_ids, one per line
      rake granblue:fetch_wiki_data build=shadow            # Characters: build the changed ones afterwards (or build=write)

    Prints a summary: fetched (unchanged = same text as stored, changed), skipped, errors,
    and the changed granblue_ids. Character writes don't queue a build per row; without
    build= the task prints the build command to run next.
  DESC
  task fetch_wiki_data: :environment do
    ActiveRecord::Base.logger.level = Logger::WARN if ActiveRecord::Base.logger && ENV['debug'] != 'true'

    type = (ENV['type'] || 'Character').classify
    valid_types = %w[Character Weapon Summon]
    abort "Error: Invalid type '#{type}'. Must be one of: #{valid_types.join(', ')}" unless valid_types.include?(type)

    begin
      ids = CharacterSkills::SourceFetch.ids([ENV.fetch('id', nil), ENV.fetch('ids', nil)].compact.join(','))
      rarities = CharacterSkills::SourceFetch.rarities(ENV.fetch('rarity', nil))
      build = CharacterSkills::SourceFetch.build_mode(ENV.fetch('build', nil))
    rescue CharacterSkills::SourceFetch::OptionError => e
      abort "Error: #{e.message}"
    end
    abort 'Error: build= only applies to type=Character.' if build && type != 'Character'

    delay = Granblue::WikiThrottle.clamp(ENV['delay'].presence, warn: method(:puts))
    fetch = Granblue::WikiDataFetch.new(type.constantize, ids: ids, rarities: rarities,
                                                          force: ENV['force'] == 'true', delay: delay)

    summary = Character.without_skill_build { fetch.call }
    if type == 'Character'
      CharacterSkills::SourceFetch.finish(summary, build: build, changed_out: ENV['changed_out'].presence)
    elsif ENV['changed_out'].present?
      summary.write_changed(ENV['changed_out'])
    end
  end

  desc <<~DESC
    Re-fetch wiki_raw for Weapons that are missing it or stale — i.e. the wiki
    page likely changed since we last fetched (new uncap/transcendence). Stale =
    wiki_raw blank, never stamped, or latest_date newer than wiki_raw_fetched_at.

    Usage:
      rake granblue:refresh_stale_wiki_data            # all missing/stale weapons
      rake granblue:refresh_stale_wiki_data days=30    # also any weapon updated in last 30 days
      rake granblue:refresh_stale_wiki_data limit=50   # cap the batch
      rake granblue:refresh_stale_wiki_data delay=3.0  # seconds between requests (default and minimum 2.0)
  DESC
  task refresh_stale_wiki_data: :environment do
    days  = ENV['days'].presence&.to_i
    limit = ENV['limit'].presence&.to_i
    delay = Granblue::WikiThrottle.clamp(ENV['delay'].presence, warn: method(:puts))

    base = Weapon.where.not(wiki_en: [nil, ''])
    stale = base.where(
      "wiki_raw IS NULL OR wiki_raw = '' OR wiki_raw_fetched_at IS NULL OR latest_date > wiki_raw_fetched_at"
    )
    stale = stale.or(base.where('latest_date > ?', days.days.ago.to_date)) if days

    weapons = (limit ? stale.limit(limit) : stale).to_a
    total = weapons.size
    puts "Refreshing wiki_raw for #{total} weapons (#{delay}s between requests)..."

    errors = []
    count = 0
    weapons.each_with_index do |weapon, i|
      begin
        Granblue::WikiFetcher.new(delay: delay).fetch_and_store(weapon) # also refreshes weapon_sources
        count += 1
        puts "  (#{i + 1}/#{total}) #{weapon.name_en}"
      rescue StandardError => e
        errors << "#{weapon.granblue_id} (#{weapon.name_en}): #{e.message}"
        puts "  (#{i + 1}/#{total}) ERROR #{weapon.name_en}: #{e.message}"
      end
      sleep delay
    end

    puts "Refreshed #{count}/#{total} weapons. Errors: #{errors.size}"
    errors.each { |e| puts "  - #{e}" }
  end
end
