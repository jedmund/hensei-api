# frozen_string_literal: true

namespace :granblue do
  desc <<~DESC
    Download Japanese wiki (gbf-wiki.com) HTML into wiki_raw_jp. Throttled.

    Usage:
      rake granblue:download_jp_wiki                         # characters, missing only
      rake granblue:download_jp_wiki model=summon limit=50
      rake granblue:download_jp_wiki model=weapon            # weapons (now supported)
      rake granblue:download_jp_wiki force=true throttle=2
  DESC
  task download_jp_wiki: :environment do
    ActiveRecord::Base.logger.level = Logger::WARN unless ENV['debug'] == 'true'

    model = (ENV['model'].presence || 'character').classify.constantize
    Granblue::Downloaders::JpWikiDownloader.backfill(
      model: model,
      limit: ENV['limit']&.to_i,
      throttle: (ENV['throttle'] || Granblue::Downloaders::JpWikiDownloader::DEFAULT_THROTTLE).to_f,
      force: ENV['force'] == 'true',
      debug: ENV['debug'] == 'true'
    )
  end
end
