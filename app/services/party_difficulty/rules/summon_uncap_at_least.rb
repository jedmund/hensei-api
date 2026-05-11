# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when at least min_count summons (main or sub — friend summons are
    # excluded since they belong to the player who joined the raid) have
    # uncap_level >= min_uncap_level. Optionally filter by whether the summon
    # is gacha ("gacha") or free ("free") using its promotions array.
    #
    # params: { "min_uncap_level": 5, "min_count": 1, "gacha_filter": "gacha"|"free"|"any" }
    class SummonUncapAtLeast < Base
      def self.component
        'summon'
      end

      def self.validate_params(params)
        params = (params || {}).with_indifferent_access
        params[:min_uncap_level].to_i.positive? ? [] : ['min_uncap_level must be > 0']
      end

      def matching_count(party)
        min_level = params[:min_uncap_level].to_i
        filter = params[:gacha_filter].to_s

        party.summons
             .reject { |gs| gs.friend == true }
             .select { |gs| matches_gacha_filter?(gs.summon, filter) }
             .count { |gs| gs.uncap_level.to_i >= min_level }
      end

      private

      def matches_gacha_filter?(summon, filter)
        return true if filter.blank? || filter == 'any' || summon.nil?

        promotions = Array(summon.promotions)
        case filter
        when 'gacha' then promotions.any?
        when 'free' then promotions.empty?
        else true
        end
      end
    end
  end
end
