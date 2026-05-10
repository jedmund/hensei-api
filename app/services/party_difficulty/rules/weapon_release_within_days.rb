# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when at least min_count weapons were released within the last `days` days.
    # This is the time-decay rule for weapons — recently released items make a
    # team harder to assemble.
    #
    # params: { "days": 180, "min_count": 1 }
    class WeaponReleaseWithinDays < Base
      def self.component
        'weapon'
      end

      def self.validate_params(params)
        params = (params || {}).with_indifferent_access
        params[:days].to_i.positive? ? [] : ['days must be > 0']
      end

      def matching_count(party)
        cutoff = params[:days].to_i.days.ago.to_date
        party.weapons.count { |gw| gw.weapon&.release_date && gw.weapon.release_date >= cutoff }
      end
    end
  end
end
