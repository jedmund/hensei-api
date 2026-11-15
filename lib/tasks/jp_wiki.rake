# frozen_string_literal: true

namespace :granblue do
  desc <<~DESC
    Download Japanese wiki (gbf-wiki.com) HTML into wiki_raw_jp. At least 2s between requests.

    Usage:
      rake granblue:download_jp_wiki                         # characters, missing only
      rake granblue:download_jp_wiki missing=true            # only rows with a blank wiki_raw_jp
      rake granblue:download_jp_wiki ids=3040252000,3040164000          # these granblue_ids (both style rows)
      rake granblue:download_jp_wiki ids=3040252000 force=true          # refetch them even if cached
      rake granblue:download_jp_wiki model=summon limit=50
      rake granblue:download_jp_wiki model=weapon            # weapons (now supported)
      rake granblue:download_jp_wiki force=true throttle=2   # refetch every cached row
      rake granblue:download_jp_wiki changed_out=tmp/jp_changed.txt     # write the changed granblue_ids
      rake granblue:download_jp_wiki build=shadow            # characters: build the changed ones afterwards (or build=write)

    Prints a summary: fetched (unchanged = same HTML as stored, changed), skipped, errors.
    Character writes don't queue a build per row; without build= the task prints the
    build command to run next.
  DESC
  task download_jp_wiki: :environment do
    ActiveRecord::Base.logger.level = Logger::WARN if ActiveRecord::Base.logger && ENV['debug'] != 'true'

    model = (ENV['model'].presence || 'character').classify.constantize
    begin
      ids = CharacterSkills::SourceFetch.ids(ENV.fetch('ids', nil))
      build = CharacterSkills::SourceFetch.build_mode(ENV.fetch('build', nil))
    rescue CharacterSkills::SourceFetch::OptionError => e
      abort "Error: #{e.message}"
    end
    abort 'Error: build= only applies to model=character.' if build && model != Character

    result = Character.without_skill_build do
      Granblue::Downloaders::JpWikiDownloader.backfill(
        model: model,
        limit: ENV['limit']&.to_i,
        throttle: (ENV['throttle'] || Granblue::Downloaders::JpWikiDownloader::DEFAULT_THROTTLE).to_f,
        force: ENV['force'] == 'true',
        debug: ENV['debug'] == 'true',
        ids: ids,
        missing: ENV['missing'] == 'true'
      )
    end

    if model == Character
      CharacterSkills::SourceFetch.finish(result[:summary], build: build, changed_out: ENV['changed_out'].presence)
    elsif ENV['changed_out'].present?
      result[:summary].write_changed(ENV['changed_out'])
    end
  end

  desc <<~DESC
    Store the Japanese aura row for summons with no page of their own on gbf-wiki.com (R and
    SR summons, and SSRs whose page isn't written yet), from the 召喚石R / 召喚石SR / 召喚石SSR
    list pages: three requests, at least 2s apart. A summon's own page is never replaced.

    Usage:
      rake granblue:download_jp_summon_lists
      rake granblue:download_jp_summon_lists ids=2020012000,2040454000
  DESC
  task download_jp_summon_lists: :environment do
    ActiveRecord::Base.logger.level = Logger::WARN if ActiveRecord::Base.logger
    ids = ENV['ids'].presence&.split(',')&.map(&:strip)
    Granblue::Downloaders::JpSummonListDownloader.backfill(
      ids: ids, throttle: (ENV['throttle'] || Granblue::Downloaders::JpWikiDownloader::DEFAULT_THROTTLE).to_f
    )
  end
end
