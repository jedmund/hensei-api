# frozen_string_literal: true

module Granblue
  # Fetches an entity's gbf.wiki page and stores the raw wikitext, following
  # #REDIRECT pages (updating wiki_en to the target). Shared by the per-entity
  # fetch_wiki endpoints and the wiki rake tasks.
  class WikiFetcher
    class MissingPageError < StandardError; end

    # entity: any model with wiki_en / wiki_raw (Weapon, Character, Summon).
    # Returns the stored wikitext.
    def fetch_and_store(entity)
      raise MissingPageError, 'No wiki page configured' if entity.wiki_en.blank?

      wiki = Parsers::Wiki.new
      text = wiki.fetch(entity.wiki_en)

      if (redirect = text.match(/#REDIRECT \[\[(.*?)\]\]/))
        entity.update!(wiki_en: redirect[1])
        text = wiki.fetch(redirect[1])
      end

      attrs = { wiki_raw: text }
      attrs[:wiki_raw_fetched_at] = Time.current if entity.has_attribute?(:wiki_raw_fetched_at)
      entity.update!(attrs)
      text
    end
  end
end
