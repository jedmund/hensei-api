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

        party.summons
             .reject { |gs| gs.friend == true }
             .count { |gs| gs.summon && ids.include?(gs.summon.summon_series_id) }
      end

      private

      def resolved_series_ids
        @resolved_series_ids ||= begin
          ids = string_array_param(:series_ids)
          slugs = string_array_param(:slugs)
          slug_ids = resolve_slugs(slugs)
          (ids + slug_ids).uniq
        end
      end

      def resolve_slugs(slugs)
        return [] if slugs.empty?

        cache = Thread.current[:pd_summon_series_cache]
        if cache
          slugs.filter_map { |s| cache[s] }
        else
          SummonSeries.where(slug: slugs).pluck(:id)
        end
      end
    end
  end
end
