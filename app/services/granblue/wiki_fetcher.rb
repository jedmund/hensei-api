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

      page = fetch(entity)
      entity.update!(wiki_en: page.title) if page.title != entity.wiki_en

      attrs = { wiki_raw: page.text }
      attrs[:wiki_raw_fetched_at] = Time.current if entity.respond_to?(:wiki_raw_fetched_at=)
      entity.update!(attrs)
      page.text
    end

    Page = Struct.new(:title, :text, keyword_init: true)

    # Fetches a character's or summon's page without storing anything (the editor's refresh
    # preview stores it later, if they apply). Follows one #REDIRECT; → Page with the title
    # the text came from, which the caller stores as wiki_en. before_request is called
    # before each request to gbf.wiki (the caller's spacing).
    def fetch(entity, before_request: nil)
      raise MissingPageError, 'No wiki page configured' if entity.wiki_en.blank?

      wiki = Parsers::Wiki.new(store: nil) # this is the fetch step: always the network
      title = entity.wiki_en
      before_request&.call
      text = wiki.fetch(title)

      if (redirect = text.match(/#REDIRECT \[\[(.*?)\]\]/))
        title = redirect[1]
        # The target is a second request to the wiki: never right after the first. The
        # caller's spacing does it when given; otherwise this fetcher's own delay (≥2s).
        if before_request
          before_request.call
        else
          WikiThrottle.wait(WikiThrottle.clamp(@delay))
        end
        text = wiki.fetch(title)
      end

      Page.new(title: title, text: text)
    end
  end
end
