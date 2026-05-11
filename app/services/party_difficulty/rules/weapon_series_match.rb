# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when at least min_count weapons in the party belong to one of the
    # specified weapon series. Series may be referenced by id (UUID string) or
    # by slug (e.g. "grand", "providence").
    #
    # params: { "series_ids": ["uuid", ...], "slugs": ["grand", ...], "min_count": 1 }
    class WeaponSeriesMatch < Base
      def self.component
        'weapon'
      end

      def self.validate_params(params)
        errors = []
        params = (params || {}).with_indifferent_access
        if params[:series_ids].blank? && params[:slugs].blank?
          errors << 'series_ids or slugs must be provided'
        end
        errors
      end

      def matching_count(party)
        matching_weapons(party).size
      end

      def match_factors(party)
        matching_weapons(party).map { |gw| decay_factor_for(gw.weapon&.release_date) }
      end

      private

      def matching_weapons(party)
        ids = resolved_series_ids
        return [] if ids.empty?

        party.weapons.select { |gw| gw.weapon && ids.include?(gw.weapon.weapon_series_id) }
      end

      def resolved_series_ids
        @resolved_series_ids ||= begin
          ids = string_array_param(:series_ids)
          slug_ids = resolve_slugs(string_array_param(:slugs))
          (ids + slug_ids).uniq
        end
      end

      def resolve_slugs(slugs)
        return [] if slugs.empty?

        cache = Thread.current[:pd_weapon_series_cache]
        if cache
          slugs.filter_map { |s| cache[s] }
        else
          WeaponSeries.where(slug: slugs).pluck(:id)
        end
      end
    end
  end
end
