# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when at least min_count of the specified weapon ids are present.
    # Useful for "team requires N copies of weapon X" patterns.
    #
    # params: { "weapon_ids": ["uuid", ...], "min_count": 3 }
    class WeaponSpecificMatch < Base
      def self.component
        'weapon'
      end

      def self.validate_params(params)
        params = (params || {}).with_indifferent_access
        params[:weapon_ids].present? ? [] : ['weapon_ids must be provided']
      end

      def matching_count(party)
        ids = string_array_param(:weapon_ids)
        return 0 if ids.empty?

        party.weapons.count { |gw| ids.include?(gw.weapon_id.to_s) }
      end
    end
  end
end
