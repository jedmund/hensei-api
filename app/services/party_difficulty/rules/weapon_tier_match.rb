# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Multi-filter match used to score specific high-end weapon tiers like
    # "Destroyer at ULB" or "Celestial ULB with awakening 5+". Counts weapons
    # that satisfy every supplied filter; filters are ANDed together.
    #
    # params: {
    #   "series_slugs": ["destroyer"],
    #   "min_uncap_level": 5,
    #   "min_transcendence_step": 3,
    #   "min_awakening_level": 5,
    #   "awakening_id": "uuid",
    #   "gacha_filter": "gacha" | "free" | "any"
    # }
    class WeaponTierMatch < Base
      def self.component
        'weapon'
      end

      def self.validate_params(params)
        params = (params || {}).with_indifferent_access
        has_filter = params[:series_slugs].present? ||
                     params[:series_ids].present? ||
                     params[:min_uncap_level].to_i.positive? ||
                     params[:min_transcendence_step].to_i.positive? ||
                     params[:min_awakening_level].to_i.positive?
        has_filter ? [] : ['at least one filter must be provided']
      end

      def matching_count(party)
        matching_weapons(party).size
      end

      def match_factors(party)
        matching_weapons(party).map { |gw| decay_factor_for(gw.weapon&.release_date) }
      end

      private

      def matching_weapons(party)
        party.weapons.select { |gw| matches?(gw) }
      end

      def matches?(grid_weapon)
        weapon = grid_weapon.weapon
        return false unless weapon

        return false unless matches_series?(weapon)
        return false unless matches_gacha?(weapon)
        return false unless matches_uncap?(grid_weapon)
        return false unless matches_transcendence?(grid_weapon)

        matches_awakening?(grid_weapon)
      end

      def matches_series?(weapon)
        ids = resolved_series_ids
        return true if ids.empty?

        ids.include?(weapon.weapon_series_id)
      end

      def matches_gacha?(weapon)
        filter = params[:gacha_filter].to_s
        return true if filter.blank? || filter == 'any'

        promotions = Array(weapon.promotions)
        case filter
        when 'gacha' then promotions.any?
        when 'free' then promotions.empty?
        else true
        end
      end

      def matches_uncap?(grid_weapon)
        in_range?(grid_weapon.uncap_level.to_i, params[:min_uncap_level], params[:max_uncap_level])
      end

      def matches_transcendence?(grid_weapon)
        in_range?(grid_weapon.transcendence_step.to_i,
                  params[:min_transcendence_step], params[:max_transcendence_step])
      end

      def matches_awakening?(grid_weapon)
        awakening_id = params[:awakening_id].presence&.to_s
        return false if awakening_id && grid_weapon.awakening_id.to_s != awakening_id

        in_range?(grid_weapon.awakening_level.to_i,
                  params[:min_awakening_level], params[:max_awakening_level])
      end

      def in_range?(value, min_param, max_param)
        min = min_param.to_i
        max_present = max_param.present?
        max = max_param.to_i

        return false if min.positive? && value < min
        return false if max_present && value > max

        true
      end

      def resolved_series_ids
        @resolved_series_ids ||= begin
          ids = string_array_param(:series_ids)
          slug_ids = resolve_slugs(string_array_param(:series_slugs))
          (ids + slug_ids).uniq
        end
      end

      def resolve_slugs(slugs)
        return [] if slugs.empty?

        cache = Thread.current[:pd_weapon_series_cache]
        if cache && slugs.all? { |s| cache.key?(s) }
          slugs.filter_map { |s| cache[s] }
        else
          WeaponSeries.where(slug: slugs).pluck(:id)
        end
      end
    end
  end
end
