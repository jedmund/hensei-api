# frozen_string_literal: true

module Api
  module V1
    class WeaponSkillDataController < Api::V1::ApiController
      include Concerns::WeaponSkillRowGuard

      before_action :ensure_editor_role, only: %i[create update destroy]
      before_action :set, only: %i[update destroy]

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

      # POST /weapon_skill_data
      def create
        datum = WeaponSkillDatum.new(datum_params)
        datum.manually_edited_at = Time.current
        datum.save!
        render json: WeaponSkillDatumBlueprint.render(datum), status: :created
      end

      # PATCH /weapon_skill_data/:id
      def update
        @datum.assign_attributes(datum_params)
        @datum.manually_edited_at = Time.current
        @datum.save!
        render json: WeaponSkillDatumBlueprint.render(@datum)
      end

      # DELETE /weapon_skill_data/:id — 409 with blast radius unless force=true
      def destroy
        guarded_destroy(@datum)
      end

      private

      def set
        @datum = WeaponSkillDatum.find(params[:id])
      end

      def datum_params
        params.require(:weapon_skill_datum)
              .permit(:modifier, :boost_type, :series, :size, :formula_type,
                      :sl1, :sl10, :sl15, :sl20, :sl25, :coefficient, :max_value,
                      :aura_boostable, :weapon_skill_version_id)
      end
    end
  end
end
