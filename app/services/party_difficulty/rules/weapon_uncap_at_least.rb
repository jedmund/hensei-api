# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when at least min_count weapons have uncap_level >= min_uncap_level.
    #
    # params: { "min_uncap_level": 5, "min_count": 5 }
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
        party.weapons.count { |gw| gw.uncap_level.to_i >= min_level }
      end
    end
  end
end
