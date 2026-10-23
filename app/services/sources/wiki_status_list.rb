# frozen_string_literal: true

module Sources
  # Fetches gbf.wiki's Module:StatusList (one request, after the wiki delay, with the app's wiki
  # user agent) into the wiki_status_list Source row, writing only when it changed. Refuses a body
  # that doesn't parse, lacks buffs or debuffs, or has a name that won't resolve
  # (StatusList.validate!), so a broken page can't replace a good list.
  class WikiStatusList
    Result = Struct.new(:source, :changed, keyword_init: true)

    def self.fetch!(wiki: Granblue::Parsers::Wiki.new(store: nil), sleeper: ->(seconds) { sleep(seconds) })
      sleeper.call(Granblue::WikiThrottle::MIN_DELAY)
      body = wiki.fetch_raw(Granblue::Parsers::StatusList::KEY, kind: nil)
      raise "gbf.wiki didn't return #{Granblue::Parsers::StatusList::KEY}" if body.blank?

      Granblue::Parsers::StatusList.validate!(body)
      put = Source.put(nil, Granblue::Parsers::StatusList::KIND, body, key: Granblue::Parsers::StatusList::KEY,
                                                                       fetched_at: Time.current)
      Result.new(source: put.source, changed: put.changed?)
    end
  end
end
