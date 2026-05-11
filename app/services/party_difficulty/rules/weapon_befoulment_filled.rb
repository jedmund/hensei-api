# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when at least min_count weapons have a befoulment modifier set.
    #
    # params: { "min_count": 1 }
    class WeaponBefoulmentFilled < Base
      def self.component
        'weapon'
      end

      def matching_count(party)
        party.weapons.count { |gw| gw.befoulment_modifier_id.present? }
      end
    end
  end
end
