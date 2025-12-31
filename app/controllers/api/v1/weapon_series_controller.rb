# frozen_string_literal: true

module Api
  module V1
    class WeaponSeriesController < Api::V1::ApiController
      before_action :set_weapon_series, only: %i[show update destroy]
      before_action :ensure_editor_role, only: %i[create update destroy]

      # GET /weapon_series
      def index
        weapon_series = WeaponSeries.ordered
        render json: WeaponSeriesBlueprint.render(weapon_series)
      end

      # GET /weapon_series/:id
      def show
        render json: WeaponSeriesBlueprint.render(@weapon_series, view: :full)
      end

      # POST /weapon_series
      def create
        weapon_series = WeaponSeries.new(weapon_series_params)

        if weapon_series.save
          render json: WeaponSeriesBlueprint.render(weapon_series, view: :full), status: :created
        else
          render_validation_error_response(weapon_series)
        end
      end

      # PATCH/PUT /weapon_series/:id
      def update
        if @weapon_series.update(weapon_series_params)
          render json: WeaponSeriesBlueprint.render(@weapon_series, view: :full)
        else
          render_validation_error_response(@weapon_series)
        end
      end

      # DELETE /weapon_series/:id
      def destroy
        if @weapon_series.weapons.exists?
          render json: ErrorBlueprint.render(nil, error: {
            message: 'Cannot delete series with associated weapons',
            code: 'has_dependencies'
          }), status: :unprocessable_entity
        else
          @weapon_series.destroy!
          head :no_content
        end
      end

      private

      def set_weapon_series
        # Support lookup by slug or UUID
        @weapon_series = WeaponSeries.find_by(slug: params[:id]) || WeaponSeries.find(params[:id])
      end

      def ensure_editor_role
        return if current_user&.role && current_user.role >= 7

        Rails.logger.warn "[WEAPON_SERIES] Unauthorized access attempt by user #{current_user&.id}"
        render json: { error: 'Unauthorized - Editor role required' }, status: :unauthorized
      end

      def weapon_series_params
        params.require(:weapon_series).permit(
          :name_en, :name_jp, :slug, :order,
          :extra, :element_changeable, :has_weapon_keys,
          :has_awakening, :augment_type
        )
      end
    end
  end
end
