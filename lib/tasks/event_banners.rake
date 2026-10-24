# frozen_string_literal: true

namespace :events do
  # Wiki pages of the recurring series, by Event::SERIES. Their header image
  # doesn't change between runs, so it's fetched once and stored at
  # events/series/<series>.webp.
  series_pages = {
    'unite_and_fight' => 'Unite and Fight',
    'dread_barrage' => 'Dread Barrage',
    'rise_of_the_beasts' => 'Rise of the Beasts',
    'records_of_the_ten' => 'Records of the Ten'
  }.freeze

  desc "Fetch recurring events' header images from gbf.wiki (FORCE=1 replaces, SERIES=a,b limits)"
  task fetch_series_images: :environment do
    user_agent = Rails.application.credentials.wiki_user_agent
    abort 'wiki_user_agent credential is missing' if user_agent.blank?

    headers = { 'User-Agent' => user_agent }
    api = Granblue::Parsers::Wiki.base_uri
    storage = IconStorage.new
    requests = 0
    # Every wiki request is at least 2s after the previous one
    wiki_get = lambda do |url, **options|
      sleep 2 if requests.positive?
      requests += 1
      HTTParty.get(url, headers: headers, timeout: 60, **options)
    end

    only = ENV['SERIES'].to_s.split(',').map(&:strip).reject(&:empty?)
    series_pages.each do |series, page|
      next if only.any? && only.exclude?(series)

      key = "#{Event::IMAGE_PREFIX}/series/#{series}.webp"
      if ENV['FORCE'].blank? && storage.exist?(key)
        puts "#{series}: already stored at #{key}"
        next
      end

      parsed = wiki_get.call(api, query: { action: 'parse', page: page, prop: 'wikitext', format: 'json',
                                          formatversion: 2 })
      file = EventTopImage.file_name(parsed.parsed_response.dig('parse', 'wikitext'))
      unless parsed.code == 200 && file
        puts "#{series}: no header image on #{page} (HTTP #{parsed.code})"
        next
      end

      info = wiki_get.call(api, query: { action: 'query', titles: "File:#{file}", prop: 'imageinfo',
                                         iiprop: 'url', format: 'json' })
      pages = info.parsed_response.dig('query', 'pages') || {}
      url = pages.values.first&.dig('imageinfo', 0, 'url')
      unless info.code == 200 && url
        puts "#{series}: no URL for File:#{file} (HTTP #{info.code})"
        next
      end

      image = wiki_get.call(url)
      unless image.code == 200
        puts "#{series}: download failed (HTTP #{image.code})"
        next
      end

      # Store everything as WebP so the key is predictable and transparent
      # PNGs keep their transparency
      webp = MiniMagick::Image.read(image.body.b)
      webp.format('webp') { |convert| convert.quality(90) }
      storage.put(key, webp.to_blob, content_type: 'image/webp')
      puts "#{series}: stored #{key} from File:#{file} (#{webp.width}x#{webp.height})"
    end
  end
end
