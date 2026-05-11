# frozen_string_literal: true

module Api
  module V1
    ##
    # Editor staging layer for the difficulty editor. Stages create/update/destroy
    # against Difficulty / DifficultyRule / DifficultyComponent, then promotes
    # them to canonical via #commit. Editors live with their own draft set; one
    # user's drafts are invisible to another.
    class DifficultyDraftsController < Api::V1::ApiController
      before_action :doorkeeper_authorize!
      before_action :ensure_editor_role
      before_action :load_workspace

      def index
        render json: { drafts: @workspace.drafts.map { |d| serialize(d) },
                       pending_count: @workspace.pending_count }
      end

      def diff
        render json: { diff: @workspace.diff, pending_count: @workspace.pending_count }
      end

      def create
        params_hash = draft_params
        draft = @workspace.stage!(
          target_type: params_hash[:target_type],
          target_id: params_hash[:target_id],
          operation: params_hash[:operation],
          attributes: params_hash[:attributes].presence || {}
        )
        render json: serialize(draft), status: :created
      rescue ArgumentError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def destroy
        draft = DifficultyDraft.for_user(current_user).find_by(id: params[:id])
        return render_not_found_response('difficulty_draft') unless draft

        @workspace.delete_draft!(draft)
        head :no_content
      end

      def discard_all
        discarded = @workspace.discard!
        render json: { discarded: discarded }
      end

      # POST /difficulty_drafts/:id/upload_image
      # Body: { image: <base64-png>, filename: <string?> }
      def upload_image
        draft = DifficultyDraft.for_user(current_user).find_by(id: params[:id])
        return render_not_found_response('difficulty_draft') unless draft

        @workspace.attach_image!(draft, image_data: params[:image], filename: params[:filename])
        render json: serialize(draft.reload)
      rescue ArgumentError => e
        render json: { error: e.message }, status: :unprocessable_entity
      rescue PartyDifficulty::DraftWorkspace::ImageValidationError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def commit
        note = params[:note].to_s
        log = @workspace.commit!(note: note)
        render json: {
          ruleset_version_after: log.ruleset_version_after,
          committed_at: log.committed_at,
          note: log.note,
          change_log_id: log.id
        }
      rescue PartyDifficulty::StaleDraftError => e
        render json: {
          error: 'stale_draft',
          message: e.message,
          draft_id: e.draft_id,
          target_type: e.target_type,
          target_id: e.target_id
        }, status: :conflict
      end

      private

      def load_workspace
        @workspace = PartyDifficulty::DraftWorkspace.for(current_user)
      end

      def draft_params
        permitted = params.require(:draft).permit(:target_type, :target_id, :operation, attributes: {})
        raw_attrs = params.require(:draft)[:attributes]
        permitted[:attributes] = raw_attrs.to_unsafe_h if raw_attrs.is_a?(ActionController::Parameters)
        permitted
      end

      def serialize(draft)
        {
          id: draft.id,
          target_type: draft.target_type,
          target_id: draft.target_id,
          operation: draft.operation,
          attributes: draft.attributes_payload,
          created_at: draft.created_at,
          updated_at: draft.updated_at
        }
      end
    end
  end
end
