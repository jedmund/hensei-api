# frozen_string_literal: true

module Api
  module V1
    class WeaponKeysController < Api::V1::ApiController
      def all
        conditions = {}
        conditions[:series] = request.params['series']
        conditions[:slot] = request.params['slot']
        conditions[:group] = request.params['group'] unless request.params['group'].blank?

        @keys = WeaponKey.where(conditions)
        render :all, status: :ok
      end
    end
  end
end
