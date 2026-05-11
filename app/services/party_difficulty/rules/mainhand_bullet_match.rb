# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when the party's mainhand weapon has any of the specified bullets
    # slotted. Scores under the `accessory` component (alongside manaturas /
    # shields) since rare bullets are gated like accessories rather than like
    # weapon investment.
    #
    # params: { "bullet_ids": ["uuid", ...] }
    class MainhandBulletMatch < Base
      def self.component
        'accessory'
      end

      def self.validate_params(params)
        params = (params || {}).with_indifferent_access
        params[:bullet_ids].present? ? [] : ['bullet_ids must be provided']
      end

      def applies?(party)
        matching_count(party).positive?
      end

      def matching_count(party)
        ids = string_array_param(:bullet_ids)
        return 0 if ids.empty?

        mainhand = party.weapons.find(&:mainhand)
        return 0 unless mainhand

        bullets = mainhand.grid_weapon_bullets.to_a
        bullets.any? { |b| ids.include?(b.bullet_id.to_s) } ? 1 : 0
      end
    end
  end
end
