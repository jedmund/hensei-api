# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires for weapons whose recruited character belongs to one of the given
    # seasons (Valentine=1, Formal=2, Summer=3, Halloween=4, Holiday=5).
    # Supports per-match age decay so older seasonal weapons score lower than
    # recent ones — pass `decay_per_year` (e.g. 0.1 = 10% per year, with a
    # floor at `decay_floor` or 0.1).
    #
    # params: {
    #   "seasons": [2],
    #   "min_count": 1,
    #   "scale_by_count": true,
    #   "max_count": 3,
    #   "decay_per_year": 0.1
    # }
    class WeaponSeasonalMatch < Base
      def self.component
        'weapon'
      end

      def self.validate_params(params)
        params = (params || {}).with_indifferent_access
        params[:seasons].present? ? [] : ['seasons must be provided']
      end

      def matching_count(party)
        matching_weapons(party).size
      end

      def match_factors(party)
        matching_weapons(party).map { |gw| decay_factor_for(gw.weapon&.release_date) }
      end

      private

      def matching_weapons(party)
        seasons = Array(params[:seasons]).map(&:to_i)
        return [] if seasons.empty?

        party.weapons.select do |gw|
          season = gw.weapon&.recruited_character&.season
          season.present? && seasons.include?(season.to_i)
        end
      end
    end
  end
end
