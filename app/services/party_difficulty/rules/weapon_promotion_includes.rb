# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when at least min_count weapons have one of the specified promotion
    # values in their `promotions` array (Premium, Classic, Flash, Legend, etc.).
    #
    # params: { "promotions": ["Flash", "Legend"], "min_count": 2 }
    class WeaponPromotionIncludes < Base
      def self.component
        'weapon'
      end

      def self.validate_params(params)
        params = (params || {}).with_indifferent_access
        params[:promotions].present? ? [] : ['promotions must be provided']
      end

      def matching_count(party)
        promotions = string_array_param(:promotions)
        return 0 if promotions.empty?

        party.weapons.count do |gw|
          weapon_promotions = Array(gw.weapon&.promotions)
          weapon_promotions.intersect?(promotions)
        end
      end
    end
  end
end
