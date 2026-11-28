# frozen_string_literal: true

namespace :banner_history do
  desc 'Fetch gbf.wiki Banner History pages into sources (one request every few seconds). ' \
       'Optional range: rake "banner_history:fetch[2020,2026]"'
  task :fetch, %i[from to] => :environment do |_, args|
    from = (args[:from] || BannerHistory::SourcePages::FIRST_YEAR).to_i
    to = (args[:to] || Time.current.year).to_i
    BannerHistory::SourcePages.new.fetch(from..to).each { |year, status| puts "#{year}: #{status}" }
  end

  desc 'Report on the cached Banner History: timeline, featured items and unresolved names (stores nothing)'
  task report: :environment do
    BannerHistory::Report.new.run
  end
end
