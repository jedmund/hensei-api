# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Counts how many slotted bullets on the party's mainhand weapon match
    # the configured bullet_ids. Scores under the `accessory` component
    # (alongside manaturas / shields) since rare bullets are gated like
    # accessories rather than like weapon investment. Combine with
    # scale_by_count so a mainhand carrying multiple top-tier bullets scores
    # more than one with a single match.
    #
    # params: { "bullet_ids": ["uuid", ...], "min_count": 1, "scale_by_count": true, "max_count": 4 }
    class MainhandBulletMatch < Base
      def self.component
        'accessory'
      end

      def self.validate_params(params)
        params = (params || {}).with_indifferent_access
        params[:bullet_ids].present? ? [] : ['bullet_ids must be provided']
      end

      def matching_count(party)
        ids = string_array_param(:bullet_ids)
        return 0 if ids.empty?

        mainhand = party.weapons.find(&:mainhand)
        return 0 unless mainhand

        mainhand.grid_weapon_bullets.count { |b| ids.include?(b.bullet_id.to_s) }
      end
    end
  end
end
