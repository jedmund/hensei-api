# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when the party's accessory matches one of the given ids OR is of
    # one of the given accessory_types (1=shield, 2=manatura).
    #
    # params: { "accessory_ids": ["uuid", ...], "accessory_types": [1, 2] }
    class AccessoryMatch < Base
      def self.component
        'accessory'
      end

      def self.validate_params(params)
        params = (params || {}).with_indifferent_access
        if params[:accessory_ids].blank? && params[:accessory_types].blank?
          ['accessory_ids or accessory_types must be provided']
        else
          []
        end
      end

      def applies?(party)
        return false unless party.accessory

        ids = string_array_param(:accessory_ids)
        types = Array(params[:accessory_types]).map(&:to_i)

        id_match = ids.any? && ids.include?(party.accessory_id.to_s)
        type_match = types.any? && types.include?(party.accessory.accessory_type.to_i)

        ids.empty? && types.empty? ? false : (id_match || type_match)
      end

      def matching_count(party)
        applies?(party) ? 1 : 0
      end
    end
  end
end
