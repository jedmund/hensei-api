# frozen_string_literal: true

module Api
  module V1
    class DifficultiesController < Api::V1::ApiController
      before_action :doorkeeper_authorize!, only: %i[create update destroy]
      before_action :ensure_editor_role, only: %i[create update destroy]

      def index
        difficulties = if with_drafts?
                         PartyDifficulty::DraftWorkspace.for(current_user).merged_tiers
                       else
                         Difficulty.ordered
                       end
        render json: DifficultyBlueprint.render(difficulties, view: :list)
      end

      def show
        difficulty = find_difficulty(params[:id])
        return render_not_found_response('difficulty') unless difficulty

        render json: DifficultyBlueprint.render(difficulty, view: :list)
      end

      def create
        draft = PartyDifficulty::DraftWorkspace.for(current_user).stage!(
          target_type: 'Difficulty', target_id: nil, operation: 'create', attributes: difficulty_params
        )
        render json: draft_envelope(draft), status: :created
      end

      def update
        difficulty = find_difficulty(params[:id])
        return render_not_found_response('difficulty') unless difficulty

        draft = PartyDifficulty::DraftWorkspace.for(current_user).stage!(
          target_type: 'Difficulty', target_id: difficulty.id, operation: 'update', attributes: difficulty_params
        )
        render json: draft_envelope(draft)
      end

      def destroy
        difficulty = find_difficulty(params[:id])
        return render_not_found_response('difficulty') unless difficulty

        PartyDifficulty::DraftWorkspace.for(current_user).stage!(
          target_type: 'Difficulty', target_id: difficulty.id, operation: 'destroy', attributes: {}
        )
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
        params.require(:difficulty).permit(:name, :slug, :description, :min_score, :max_score, :sort_order)
      end

      def with_drafts?
        return false unless current_user&.role && current_user.role >= 7

        ActiveModel::Type::Boolean.new.cast(params[:with_drafts])
      end

      def draft_envelope(draft)
        {
          draft: {
            id: draft.id,
            target_type: draft.target_type,
            target_id: draft.target_id,
            operation: draft.operation,
            attributes: draft.attributes_payload
          }
        }
      end
    end
  end
end
