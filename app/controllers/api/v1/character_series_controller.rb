# frozen_string_literal: true

module Api
  module V1
    class CharacterSeriesController < Api::V1::ApiController
      before_action :set_character_series, only: %i[show update destroy]
      before_action :ensure_editor_role, only: %i[create update destroy]

      # GET /character_series
      def index
        character_series = CharacterSeries.ordered
        render json: CharacterSeriesBlueprint.render(character_series)
      end

      # GET /character_series/:id
      def show
        render json: CharacterSeriesBlueprint.render(@character_series, view: :full)
      end

      # POST /character_series
      def create
        character_series = CharacterSeries.new(character_series_params)

        if character_series.save
          render json: CharacterSeriesBlueprint.render(character_series, view: :full), status: :created
        else
          render_validation_error_response(character_series)
        end
      end

      # PATCH/PUT /character_series/:id
      def update
        if @character_series.update(character_series_params)
          render json: CharacterSeriesBlueprint.render(@character_series, view: :full)
        else
          render_validation_error_response(@character_series)
        end
      end

      # DELETE /character_series/:id
      def destroy
        if @character_series.characters.exists?
          render json: ErrorBlueprint.render(nil, error: {
            message: 'Cannot delete series with associated characters',
            code: 'has_dependencies'
          }), status: :unprocessable_entity
        else
          @character_series.destroy!
          head :no_content
        end
      end

      private

      def set_character_series
        # Support lookup by slug or UUID
        @character_series = CharacterSeries.find_by(slug: params[:id]) || CharacterSeries.find(params[:id])
      end

      def ensure_editor_role
        return if current_user&.role && current_user.role >= 7

        Rails.logger.warn "[CHARACTER_SERIES] Unauthorized access attempt by user #{current_user&.id}"
        render json: { error: 'Unauthorized - Editor role required' }, status: :unauthorized
      end

      def character_series_params
        params.require(:character_series).permit(:name_en, :name_jp, :slug, :order)
      end
    end
  end
end
