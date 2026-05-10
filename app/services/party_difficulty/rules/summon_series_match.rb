# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when at least min_count summons belong to one of the specified
    # summon_series (by id or slug — e.g. "providence").
    #
    # params: { "series_ids": ["uuid", ...], "slugs": ["providence", ...], "min_count": 1 }
    class SummonSeriesMatch < Base
      def self.component
        'summon'
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

        party.summons.count { |gs| gs.summon && ids.include?(gs.summon.summon_series_id) }
      end

      private

      def resolved_series_ids
        @resolved_series_ids ||= begin
          ids = string_array_param(:series_ids)
          slug_ids = string_array_param(:slugs).then do |slugs|
            slugs.empty? ? [] : SummonSeries.where(slug: slugs).pluck(:id)
          end
          (ids + slug_ids).uniq
        end
      end
    end
  end
end
