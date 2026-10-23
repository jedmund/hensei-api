# frozen_string_literal: true

module Api
  module V1
    class DifficultyComponentsController < Api::V1::ApiController
      before_action :doorkeeper_authorize!
      before_action :ensure_editor_role

      def index
        components = if with_drafts?
                       PartyDifficulty::DraftWorkspace.for(current_user).merged_components
                     else
                       DifficultyComponent.order(:name)
                     end
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

        draft = PartyDifficulty::DraftWorkspace.for(current_user).stage!(
          target_type: 'DifficultyComponent', target_id: component.id, operation: 'update',
          attributes: component_params
        )
        render json: {
          draft: {
            id: draft.id,
            target_type: draft.target_type,
            target_id: draft.target_id,
            operation: draft.operation,
            attributes: draft.attributes_payload
          }
        }
      end

      private

      def find_component(identifier)
        DifficultyComponent.find_by(id: identifier) || DifficultyComponent.find_by(name: identifier)
      end

      def component_params
        params.require(:difficulty_component).permit(:weight, :enabled, :min_count_to_score, :target_max)
      end

      def with_drafts?
        return false unless current_user&.role && current_user.role >= 7

        ActiveModel::Type::Boolean.new.cast(params[:with_drafts])
      end
    end
  end
end
