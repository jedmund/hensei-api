# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when at least min_count weapons have uncap_level >= min_uncap_level.
    # Optionally filter by whether the weapon is gacha ("gacha") or free
    # ("free") using its promotions array — gacha weapons cost more to obtain
    # so high uncaps on them typically score higher.
    #
    # params: { "min_uncap_level": 5, "min_count": 5, "gacha_filter": "gacha"|"free"|"any" }
    class WeaponUncapAtLeast < Base
      def self.component
        'weapon'
      end

      def self.validate_params(params)
        params = (params || {}).with_indifferent_access
        params[:min_uncap_level].to_i.positive? ? [] : ['min_uncap_level must be > 0']
      end

      def matching_count(party)
        min_level = params[:min_uncap_level].to_i
        filter = params[:gacha_filter].to_s

        party.weapons
             .select { |gw| matches_gacha_filter?(gw.weapon, filter) }
             .count { |gw| gw.uncap_level.to_i >= min_level }
      end

      private

      def matches_gacha_filter?(weapon, filter)
        return true if filter.blank? || filter == 'any' || weapon.nil?

        promotions = Array(weapon.promotions)
        case filter
        when 'gacha' then promotions.any?
        when 'free' then promotions.empty?
        else true
        end
      end
    end
  end
end
