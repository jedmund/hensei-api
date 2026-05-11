# frozen_string_literal: true

module Api
  module V1
    class DifficultyComponentsController < Api::V1::ApiController
      before_action :doorkeeper_authorize!
      before_action :ensure_editor_role

      def index
        components = DifficultyComponent.order(:name)
        render json: DifficultyComponentBlueprint.render(components)
      end

      def show
        component = find_component(params[:id])
        return render_not_found_response('difficulty_component') unless component

        render json: DifficultyComponentBlueprint.render(component)
      end

      def update
        component = find_component(params[:id])
        return render_not_found_response('difficulty_component') unless component

        if component.update(component_params)
          render json: DifficultyComponentBlueprint.render(component)
        else
          render_validation_error_response(component)
        end
      end

      private

      def find_component(identifier)
        DifficultyComponent.find_by(id: identifier) || DifficultyComponent.find_by(name: identifier)
      end

      def component_params
        params.require(:difficulty_component).permit(:weight, :enabled, :min_count_to_score, :target_max)
      end
    end
  end
end
