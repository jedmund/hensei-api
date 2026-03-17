# frozen_string_literal: true

module Api
  module V1
    class WeaponSeriesVariantsController < Api::V1::ApiController
      before_action :ensure_editor_role
      before_action :set_weapon_series
      before_action :set_variant, only: %i[update destroy]

      # POST /weapon_series/:weapon_series_id/weapon_series_variants
      def create
        variant = @weapon_series.weapon_series_variants.new(variant_params)

        if variant.save
          render json: WeaponSeriesVariantBlueprint.render(variant), status: :created
        else
          render_validation_error_response(variant)
        end
      end

      # PATCH/PUT /weapon_series/:weapon_series_id/weapon_series_variants/:id
      def update
        if @variant.update(variant_params)
          render json: WeaponSeriesVariantBlueprint.render(@variant)
        else
          render_validation_error_response(@variant)
        end
      end

      # DELETE /weapon_series/:weapon_series_id/weapon_series_variants/:id
      def destroy
        @variant.destroy!
        head :no_content
      end

      private

      def set_weapon_series
        @weapon_series = WeaponSeries.find_by(slug: params[:weapon_series_id]) ||
                         WeaponSeries.find(params[:weapon_series_id])
      end

      def set_variant
        @variant = @weapon_series.weapon_series_variants.find(params[:id])
      end

      def ensure_editor_role
        return if current_user&.role && current_user.role >= 7

        Rails.logger.warn "[WEAPON_SERIES_VARIANTS] Unauthorized access attempt by user #{current_user&.id}"
        render json: { error: 'Unauthorized - Editor role required' }, status: :unauthorized
      end

      def variant_params
        params.require(:weapon_series_variant).permit(
          :name, :has_weapon_keys, :has_awakening, :num_weapon_keys,
          :augment_type, :element_changeable, :extra
        )
      end
    end
  end
end
