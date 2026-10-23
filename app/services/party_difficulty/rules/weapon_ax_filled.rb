# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when at least min_count weapons have at least min_filled AX modifier
    # slots filled (proxy for AX RNG investment).
    #
    # params: { "min_filled": 1, "min_count": 3 }
    class WeaponAxFilled < Base
      def self.component
        'weapon'
      end

      def matching_count(party)
        min_filled = (params[:min_filled].presence || 1).to_i
        party.weapons.count do |gw|
          slots = [gw.ax_modifier1_id.present?, gw.ax_modifier2_id.present?].count(true)
          slots >= min_filled
        end
      end
    end
  end
end
