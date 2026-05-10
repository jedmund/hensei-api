# frozen_string_literal: true

module Api
  module V1
    class DifficultiesController < Api::V1::ApiController
      before_action :doorkeeper_authorize!, only: %i[create update destroy]
      before_action :ensure_editor_role, only: %i[create update destroy]

      def index
        difficulties = Difficulty.ordered
        render json: DifficultyBlueprint.render(difficulties, view: :list)
      end

      def show
        difficulty = Difficulty.find_by(id: params[:id]) || Difficulty.find_by(slug: params[:id])
        return render_not_found_response('difficulty') unless difficulty

        render json: DifficultyBlueprint.render(difficulty, view: :list)
      end

      def create
        difficulty = Difficulty.new(difficulty_params)
        if difficulty.save
          render json: DifficultyBlueprint.render(difficulty, view: :list), status: :created
        else
          render_validation_error_response(difficulty)
        end
      end

      def update
        difficulty = Difficulty.find_by(id: params[:id])
        return render_not_found_response('difficulty') unless difficulty

        if difficulty.update(difficulty_params)
          render json: DifficultyBlueprint.render(difficulty, view: :list)
        else
          render_validation_error_response(difficulty)
        end
      end

      def destroy
        difficulty = Difficulty.find_by(id: params[:id])
        return render_not_found_response('difficulty') unless difficulty

        difficulty.destroy
        head :no_content
      end

      private

      def difficulty_params
        params.require(:difficulty).permit(:name, :slug, :description, :min_score, :max_score, :sort_order, :color)
      end

      def ensure_editor_role
        return if current_user&.role && current_user.role >= 7

        render json: { error: 'Unauthorized - Editor role required' }, status: :unauthorized
      end
    end
  end
end
