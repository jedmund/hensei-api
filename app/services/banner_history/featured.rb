# frozen_string_literal: true

module BannerHistory
  # What a banner features, and the role each list plays: rate-ups (and
  # zodiacs) on galas, featured items on other draws, a collab's own items
  # (and the ordinary ones in its pool). 2014's banners list theirs as
  # legacy_* fields.
  module Featured
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

      entry.gala? ? 'rate_up' : 'featured'
    end
  end
end
