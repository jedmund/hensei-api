# frozen_string_literal: true

module Api
  module V1
    class SummonSeriesController < Api::V1::ApiController
      before_action :set_summon_series, only: %i[show update destroy]
      before_action :ensure_editor_role, only: %i[create update destroy]

      # GET /summon_series
      def index
        summon_series = SummonSeries.ordered
        render json: SummonSeriesBlueprint.render(summon_series)
      end

      # GET /summon_series/:id
      def show
        render json: SummonSeriesBlueprint.render(@summon_series, view: :full)
      end

      # POST /summon_series
      def create
        summon_series = SummonSeries.new(summon_series_params)

        if summon_series.save
          render json: SummonSeriesBlueprint.render(summon_series, view: :full), status: :created
        else
          render_validation_error_response(summon_series)
        end
      end

      # PATCH/PUT /summon_series/:id
      def update
        if @summon_series.update(summon_series_params)
          render json: SummonSeriesBlueprint.render(@summon_series, view: :full)
        else
          render_validation_error_response(@summon_series)
        end
      end

      # DELETE /summon_series/:id
      def destroy
        if @summon_series.summons.exists?
          render json: ErrorBlueprint.render(nil, error: {
            message: 'Cannot delete series with associated summons',
            code: 'has_dependencies'
          }), status: :unprocessable_entity
        else
          @summon_series.destroy!
          head :no_content
        end
      end

      private

      def set_summon_series
        # Support lookup by slug or UUID
        @summon_series = SummonSeries.find_by(slug: params[:id]) || SummonSeries.find(params[:id])
      end

      def ensure_editor_role
        return if current_user&.role && current_user.role >= 7

        Rails.logger.warn "[SUMMON_SERIES] Unauthorized access attempt by user #{current_user&.id}"
        render json: { error: 'Unauthorized - Editor role required' }, status: :unauthorized
      end

      def summon_series_params
        params.require(:summon_series).permit(:name_en, :name_jp, :slug, :order)
      end
    end
  end
end
