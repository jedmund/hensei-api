# frozen_string_literal: true

module Api
  module V1
    class WeaponKeysController < Api::V1::ApiController
      def all
        conditions = {}.tap do |hash|
          hash[:series] = request.params['series'] unless request.params['series'].blank?
          hash[:slot] = request.params['slot'] unless request.params['slot'].blank?
          hash[:group] = request.params['group'] unless request.params['group'].blank?
        end

        render json: WeaponKeyBlueprint.render(
          WeaponKey.where(conditions)
        )
      end
    end
  end
end
