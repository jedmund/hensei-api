# frozen_string_literal: true

module BannerHistory
  # What a banner features, and the role each list plays. rate_up lists are
  # the items the game boosted, as far as the wiki says: everything a gala
  # lists, any rateup_* list, and the showcased ("sparkable") lists on the
  # banners where those matched the game's rate-ups. A poll's or an
  # all-element banner's showcase reaches past its rate-ups, and the archive
  # labels plain "Sparkable" lists apart, so those are only featured. Element
  # banners boost more than the wiki lists; those extra rate-ups aren't known.
  # Zodiacs are available on galas, not boosted. 2014's banners list theirs as
  # legacy_* fields.
  module Featured
    # Types whose showcase matched the game's rate-ups (checked against the
    # banners the game fetcher stored, Oct–Nov 2026)
    SHOWCASE_IS_RATE_UP = %w[character_generic seasonal weapon_4star character_element summon].freeze

    module_function

    # { field => [wiki names] } for the lists a banner features
    def lists(entry)
      lists = entry.banner[:lists]
      if entry.collab?
        lists.slice('collab_wep', 'collab_sum', 'noncollab_wep')
      elsif entry.gala?
        lists.select { |field, _| field.start_with?('rateup_', 'legacy_') || field == 'zodiacs' }
      else
        lists.select { |field, _| field.start_with?('sparkable', 'rateup_', 'legacy_') }
      end
    end

    def role(entry, field)
      return 'zodiac' if field == 'zodiacs'
      return field == 'noncollab_wep' ? 'pool' : 'collab' if entry.collab?
      return 'rate_up' if entry.gala? || field.start_with?('rateup_', 'legacy_rateup')
      return 'rate_up' if field.start_with?('sparkable') && SHOWCASE_IS_RATE_UP.include?(entry.type)

      'featured'
    end
  end
end
