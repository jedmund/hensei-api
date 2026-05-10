# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when at least min_count characters are seasonal. If the `seasons`
    # param is empty, any non-Standard season counts; otherwise only the
    # specified season ints (e.g. summer, valentine).
    #
    # params: { "seasons": [9, 11], "min_count": 2 }
    class CharacterSeasonal < Base
      def self.component
        'character'
      end

      def matching_count(party)
        seasons = Array(params[:seasons]).map(&:to_i)
        standard = GranblueEnums::CHARACTER_SEASONS[:Standard]

        party.characters.count do |gc|
          season = gc.character&.season
          next false if season.nil? || season == standard

          seasons.empty? || seasons.include?(season)
        end
      end
    end
  end
end
