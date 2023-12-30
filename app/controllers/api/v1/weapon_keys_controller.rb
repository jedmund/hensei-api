# frozen_string_literal: true

module Api
  module V1
    class WeaponKeysController < Api::V1::ApiController
      def all
        conditions = {}.tap do |hash|
          hash[:series] = request.params['series'].to_i unless request.params['series'].blank?
          hash[:slot] = request.params['slot'].to_i unless request.params['slot'].blank?
          hash[:group] = request.params['group'].to_i unless request.params['group'].blank?
        end

        # Build the query based on the conditions
        weapon_keys = WeaponKey.all
        weapon_keys = weapon_keys.where('? = ANY(series)', conditions[:series]) if conditions.key?(:series)
        weapon_keys = weapon_keys.where(slot: conditions[:slot]) if conditions.key?(:slot)
        weapon_keys = weapon_keys.where(group: conditions[:group]) if conditions.key?(:group)

        render json: WeaponKeyBlueprint.render(weapon_keys)
      end
    end
  end
end
