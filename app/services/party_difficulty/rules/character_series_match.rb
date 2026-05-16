# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when at least min_count characters belong to one of the specified
    # character_series (by id or slug — e.g. "grand", "evoker", "eternal").
    # When `single_series_only` is true, a character is only counted if its
    # core series is the *only* one it belongs to — this filters out seasonal
    # variants (e.g. a Summer Eternal won't fire the Eternal rule because the
    # Summer/Yukata seasonal character rule will instead).
    #
    # params: {
    #   "slugs": ["eternal", "evoker"],
    #   "min_count": 1,
    #   "single_series_only": true
    # }
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

        single_only = params[:single_series_only] == true

        party.characters.count do |gc|
          memberships = gc.character&.character_series_records || []
          next false if single_only && memberships.size > 1

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
        resolve_slugs_via_cache(slugs, Thread.current[:pd_character_series_cache], CharacterSeries)
      end
    end
  end
end
