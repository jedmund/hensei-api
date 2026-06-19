# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when at least min_count grid weapons have any of the specified
    # bullets slotted.
    #
    # params: { "bullet_ids": ["uuid", ...], "min_count": 1 }
    class WeaponBulletMatch < Base
      def self.component
        'weapon'
      end

      def self.validate_params(params)
        params = (params || {}).with_indifferent_access
        params[:bullet_ids].present? ? [] : ['bullet_ids must be provided']
      end

      def matching_count(party)
        ids = string_array_param(:bullet_ids)
        return 0 if ids.empty?

        party.weapons.count do |gw|
          bullets = gw.grid_weapon_bullets.to_a
          bullets.any? { |b| ids.include?(b.bullet_id.to_s) }
        end
      end
    end
  end
end
