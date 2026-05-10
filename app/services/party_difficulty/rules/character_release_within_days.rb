# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when at least min_count characters were released within the last
    # `days` days (the time-decay rule for characters).
    #
    # params: { "days": 180, "min_count": 1 }
    class CharacterReleaseWithinDays < Base
      def self.component
        'character'
      end

      def self.validate_params(params)
        params = (params || {}).with_indifferent_access
        params[:days].to_i.positive? ? [] : ['days must be > 0']
      end

      def matching_count(party)
        cutoff = params[:days].to_i.days.ago.to_date
        party.characters.count { |gc| gc.character&.release_date && gc.character.release_date >= cutoff }
      end
    end
  end
end
