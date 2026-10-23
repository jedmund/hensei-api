# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when at least min_count grid characters have the perpetuity ring set.
    #
    # params: { "min_count": 1 }
    class CharacterPerpetuityRinged < Base
      def self.component
        'character'
      end

      def matching_count(party)
        party.characters.count { |gc| gc.perpetuity == true }
      end
    end
  end
end
