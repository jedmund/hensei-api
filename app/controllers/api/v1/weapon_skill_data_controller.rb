# frozen_string_literal: true

module Api
  module V1
    class WeaponSkillDataController < Api::V1::ApiController
      # GET /weapon_skill_data
      def index
        @data = WeaponSkillDatum.all
        @data = @data.where(modifier: params[:modifier]) if params[:modifier].present?
        @data = @data.where(series: params[:series]) if params[:series].present?
        @data = @data.where(size: params[:size]) if params[:size].present?

        render json: WeaponSkillDatumBlueprint.render(@data, root: :weapon_skill_data)
      end

      # GET /weapon_skill_data/:id
      def show
        @datum = WeaponSkillDatum.find(params[:id])
        render json: WeaponSkillDatumBlueprint.render(@datum)
      end
    end
  end
end
