# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when at least min_count weapons have an awakening at or above
    # min_level. Optionally restricted to a specific awakening_id.
    #
    # params: { "min_level": 5, "awakening_id": "uuid"|null, "min_count": 3 }
    class WeaponAwakeningAtLeast < Base
      def self.component
        'weapon'
      end

      def self.validate_params(params)
        params = (params || {}).with_indifferent_access
        params[:min_level].to_i.positive? ? [] : ['min_level must be > 0']
      end

      def matching_count(party)
        min_level = params[:min_level].to_i
        awakening_id = params[:awakening_id].presence&.to_s

        party.weapons.count do |gw|
          next false unless gw.awakening_id.present?
          next false if awakening_id && gw.awakening_id.to_s != awakening_id

          gw.awakening_level.to_i >= min_level
        end
      end
    end
  end
end
