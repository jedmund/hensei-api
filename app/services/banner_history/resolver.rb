# frozen_string_literal: true

module BannerHistory
  # Turns the wiki's item names into our items: by wiki page (wiki_en) first,
  # then by English name when exactly one item has it. Page names come first
  # because names repeat across versions (both Bastets are "Bastet"); straight
  # and curly apostrophes count as the same, since the wiki uses both.
  class Resolver
    Item = Struct.new(:granblue_id, :name, keyword_init: true)

    # Pages the archive names by an old title, and where the wiki redirects
    # them now (looked up 2026-11-28)
    ALIASES = {
      'Arulumaya (Christmas)' => 'Arulumaya (Holiday)',
      'Jessica (Themed)' => 'Jessica (Yukata)'
    }.freeze

    # 2014's "<element> Summons" stand for every summon of an element, not an item
    PLACEHOLDER = /\A(?:All|Fire|Water|Earth|Wind|Light|Dark) Summons\z/

    attr_reader :unresolved

    def initialize
      @index = {}
      @unresolved = Hash.new { |hash, key| hash[key] = [] }
    end

    # The model a list field holds: summons for *sum* fields and a summon
    # banner's plain "sparkable", characters for zodiacs and the archive's
    # *_char lists, weapons otherwise (2014's legacy_*char lists name weapons)
    def self.model_for(field, banner_type)
      return Character if field == 'zodiacs' || (field.end_with?('_char') && !field.start_with?('legacy_'))
      return Summon if field.include?('sum') || (field == 'sparkable' && banner_type == 'summon')

      Weapon
    end

    def self.normalize(name)
      # Curly apostrophes count as straight; invisible marks (e.g. U+200E) go
      Granblue::WikiTitle.normalize(name).to_s.tr('‘’', "''").gsub(/[\u200B-\u200F\u2060\uFEFF]/, '').downcase
    end

    # → Item or nil; a miss is remembered with where it came from
    def resolve(model, name, context:)
      return nil if name.match?(PLACEHOLDER)

      by_page, by_name = index_for(model)
      key = self.class.normalize(ALIASES.fetch(name, name))
      id = by_page[key]&.first if by_page[key]&.one?
      id ||= by_name[key].first if by_name[key]&.one?
      return Item.new(granblue_id: id, name: name) if id

      @unresolved[[model.name, name]] << context
      nil
    end

    private

    def index_for(model)
      @index[model] ||= begin
        rows = model.pluck(:granblue_id, :wiki_en, :name_en)
        group = ->(column) { rows.group_by { |row| self.class.normalize(row[column]) }.transform_values { |hits| hits.map(&:first).uniq } }
        [group.call(1), group.call(2)]
      end
    end
  end
end
