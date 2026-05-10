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
          slug_ids = string_array_param(:slugs).then do |slugs|
            slugs.empty? ? [] : CharacterSeries.where(slug: slugs).pluck(:id)
          end
          (ids + slug_ids).uniq
        end
      end
    end
  end
end
