# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when at least min_count characters belong to one of the specified
    # character_series (by id or slug — e.g. "grand", "evoker", "eternal").
    #
    # params: { "series_ids": ["uuid", ...], "slugs": ["grand", ...], "min_count": 2 }
    class CharacterSeriesMatch < Base
      def self.component
        'character'
      end

      def self.validate_params(params)
        params = (params || {}).with_indifferent_access
        if params[:series_ids].blank? && params[:slugs].blank?
          ['series_ids or slugs must be provided']
        else
          []
        end
      end

      def matching_count(party)
        ids = resolved_series_ids
        return 0 if ids.empty?

        party.characters.count do |gc|
          memberships = gc.character&.character_series_records || []
          memberships.any? { |m| ids.include?(m.id) }
        end
      end

      private

      def resolved_series_ids
        @resolved_series_ids ||= begin
          ids = string_array_param(:series_ids)
          slug_ids = resolve_slugs(string_array_param(:slugs))
          (ids + slug_ids).uniq
        end
      end

      def resolve_slugs(slugs)
        return [] if slugs.empty?

        cache = Thread.current[:pd_character_series_cache]
        if cache
          slugs.filter_map { |s| cache[s] }
        else
          CharacterSeries.where(slug: slugs).pluck(:id)
        end
      end
    end
  end
end
