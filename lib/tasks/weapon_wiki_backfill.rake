# frozen_string_literal: true

namespace :granblue do
  desc <<~DESC
    Fill blank gbf.wiki page names (wiki_en) and release/FLB/ULB dates for weapons from
    gbf.wiki's Cargo weapons table, matched by granblue_id. Never overwrites a value.
    Queries only ids not fetched before (chunks of `id IN (...)`, at least 2s apart) and
    stores the rows in the shared wiki_cargo source; the stored copy is what gets parsed.

    Usage:
      rake granblue:backfill_weapon_wiki_data                 # dry run: weapons missing wiki_en or release_date
      rake granblue:backfill_weapon_wiki_data write=true      # apply
      rake granblue:backfill_weapon_wiki_data ids=1020000400,1030005900
      rake granblue:backfill_weapon_wiki_data rarity=1,2      # R and SR only
      rake granblue:backfill_weapon_wiki_data refresh=true    # query the wiki again for every id in scope
      rake granblue:backfill_weapon_wiki_data offline=true    # no requests; only the stored rows
      rake granblue:backfill_weapon_wiki_data fetch=true      # print the wiki_raw fetch command for the filled weapons

    Weapons the wiki doesn't have are listed. Afterwards, fetch their pages with
    bin/rails granblue:fetch_wiki_data type=Weapon
  DESC
  task backfill_weapon_wiki_data: :environment do
    ActiveRecord::Base.logger.level = Logger::WARN if ActiveRecord::Base.logger && ENV['debug'] != 'true'

    begin
      ids = CharacterSkills::SourceFetch.ids(ENV.fetch('ids', nil))
      rarities = CharacterSkills::SourceFetch.rarities(ENV.fetch('rarity', nil))
    rescue CharacterSkills::SourceFetch::OptionError => e
      abort "Error: #{e.message}"
    end

    write = ENV['write'] == 'true'
    result = Granblue::WeaponWikiBackfill.new(ids: ids, rarities: rarities, write: write,
                                              refresh: ENV['refresh'] == 'true',
                                              offline: ENV['offline'] == 'true').call

    if ENV['fetch'] == 'true'
      filled = result.changes.select { |change| change.field == 'wiki_en' }.map { |change| change.weapon.granblue_id }.uniq
      puts
      if filled.empty?
        puts 'No wiki_en filled; nothing to fetch.'
      else
        puts "#{write ? 'Next' : 'After write=true'}, fetch their wiki pages with:"
        puts "  bin/rails granblue:fetch_wiki_data type=Weapon ids=#{filled.join(',')}"
      end
    end
  rescue Granblue::WeaponWikiBackfill::FetchError => e
    abort "Error: #{e.message}"
  end
end
