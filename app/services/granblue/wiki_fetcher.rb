# frozen_string_literal: true

module Granblue
  # Fetches an entity's gbf.wiki page and stores the raw wikitext, following
  # #REDIRECT pages (updating wiki_en to the target). Shared by the per-entity
  # fetch_wiki endpoints and the wiki rake tasks.
  #
  # Weapons go through the source store: the refetch also refreshes the page's
  # expansion and followed pages in weapon_sources, so a later reparse reads a
  # consistent set of sources.
  class WikiFetcher
    class MissingPageError < StandardError; end

    def initialize(delay: 0)
      @delay = delay
    end

    # entity: any model with wiki_en / wiki_raw (Weapon, Character, Summon).
    # Returns the stored wikitext.
    def fetch_and_store(entity)
      raise MissingPageError, 'No wiki page configured' if entity.wiki_en.blank?
      if entity.is_a?(Weapon)
        # one quick retry: this runs inside an admin request
        return WeaponSkills::SourceStore::Fetcher.new(delay: @delay, retries: 1, backoff: 1.0).fetch_weapon(entity)
      end

      wiki = Parsers::Wiki.new(store: nil) # this is the fetch step: always the network
      text = wiki.fetch(entity.wiki_en)

      if (redirect = text.match(/#REDIRECT \[\[(.*?)\]\]/))
        entity.update!(wiki_en: redirect[1])
        # The target is a second request to the wiki: never right after the first.
        WikiThrottle.wait(WikiThrottle.clamp(@delay))
        text = wiki.fetch(redirect[1])
      end

      attrs = { wiki_raw: text }
      attrs[:wiki_raw_fetched_at] = Time.current if entity.has_attribute?(:wiki_raw_fetched_at)
      entity.update!(attrs)
      text
    end
  end
end
