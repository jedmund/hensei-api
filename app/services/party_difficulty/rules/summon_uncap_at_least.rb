# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when at least min_count summons (main, sub, or friend) have
    # uncap_level >= min_uncap_level.
    #
    # params: { "min_uncap_level": 5, "min_count": 1 }
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
        party.summons.count { |gs| gs.uncap_level.to_i >= min_level }
      end
    end
  end
end
