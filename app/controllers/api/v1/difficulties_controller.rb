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
        difficulty = find_difficulty(params[:id])
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
        difficulty = find_difficulty(params[:id])
        return render_not_found_response('difficulty') unless difficulty

        if difficulty.update(difficulty_params)
          render json: DifficultyBlueprint.render(difficulty, view: :list)
        else
          render_validation_error_response(difficulty)
        end
      end

      def destroy
        difficulty = find_difficulty(params[:id])
        return render_not_found_response('difficulty') unless difficulty

        difficulty.destroy
        head :no_content
      end

      private

      # Looks up a Difficulty by UUID first and falls back to slug. Slug strings
      # cast to nil for the UUID column, so find_by(id:) safely returns nil for
      # slug-shaped identifiers rather than raising.
      def find_difficulty(identifier)
        Difficulty.find_by(id: identifier) || Difficulty.find_by(slug: identifier)
      end

      def difficulty_params
        params.require(:difficulty).permit(:name, :slug, :description, :min_score, :max_score, :sort_order, :color)
      end
    end
  end
end
