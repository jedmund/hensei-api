# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when at least min_count characters are seasonal. If the `seasons`
    # param is empty, any non-Standard season counts; otherwise only the
    # specified season ints (Valentine=1, Formal=2, Summer=3, Halloween=4,
    # Holiday=5). Supports per-match age decay via decay_per_year so older
    # seasonals score lower than recent releases.
    #
    # params: {
    #   "seasons": [2],
    #   "min_count": 1,
    #   "scale_by_count": true,
    #   "max_count": 3,
    #   "decay_per_year": 0.1
    # }
    class CharacterSeasonal < Base
      def self.component
        'character'
      end

      def matching_count(party)
        matching_characters(party).size
      end

      def match_factors(party)
        matching_characters(party).map { |gc| decay_factor_for(gc.character&.release_date) }
      end

      private

      def matching_characters(party)
        seasons = Array(params[:seasons]).map(&:to_i)
        standard = GranblueEnums::CHARACTER_SEASONS[:Standard]

        party.characters.select do |gc|
          season = gc.character&.season
          next false if season.nil? || season == standard

          seasons.empty? || seasons.include?(season)
        end
      end
    end
  end
end
