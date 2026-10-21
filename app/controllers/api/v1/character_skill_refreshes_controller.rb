# frozen_string_literal: true

module Api
  module V1
    # Batch refresh of characters after a balance patch (PR 5, contract C6). An editor picks
    # up to 20 character rows; CharacterSkills::RefreshJob fetches and previews each, then
    # writes the ones they choose. Only the editor who started a refresh can read or apply it.
    class CharacterSkillRefreshesController < Api::V1::ApiController
      UUID_FORMAT = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

      before_action :ensure_editor_role
      # Each refresh fetches up to 20 pages from each wiki.
      limit_requests 'character-skill-refresh', to: 5, within: 1.hour, only: :create,
                                                by: -> { "user:#{current_user&.id || client_ip}" }
      before_action :set_refresh, only: %i[show apply]

      # POST /character_skill_refreshes { character_ids: [...], refetch_jp: false } → 202 { id }
      def create
        ids = Array(params[:character_ids]).map(&:to_s).uniq
        return render_error('invalid_characters', 'Pick at least one character.') if ids.empty?

        max = CharacterSkills::RefreshBatch::MAX_CHARACTERS
        return render_error('too_many_characters', "Pick #{max} characters or fewer.") if ids.size > max

        characters = Character.where(id: ids.grep(UUID_FORMAT)).index_by(&:id)
        missing = ids - characters.keys
        return render_error('invalid_characters', "Unknown characters: #{missing.join(', ')}") if missing.any?

        batch = CharacterSkills::RefreshBatch.create(user: current_user, characters: characters.values_at(*ids),
                                                     refetch_jp: boolean_param(:refetch_jp))
        CharacterSkills::RefreshJob.perform_later(batch.id, 'preview')
        render json: { id: batch.id }, status: :accepted
      end

      # GET /character_skill_refreshes/:id
      def show
        render json: @refresh.as_json
      end

      # POST /character_skill_refreshes/:id/apply { character_ids: [...] } → 202
      # character_ids is optional (default: every previewed character).
      def apply
        unless @refresh.status == 'previewed'
          return render json: { error: 'not_previewed', message: "This refresh is #{@refresh.status}." },
                        status: :conflict
        end

        ids = params.key?(:character_ids) ? Array(params[:character_ids]).map(&:to_s) : nil
        @refresh.start_apply!(ids)
        CharacterSkills::RefreshJob.perform_later(@refresh.id, 'apply')
        render json: { id: @refresh.id }, status: :accepted
      end

      private

      # Unknown, expired and someone else's refreshes all look the same.
      def set_refresh
        @refresh = CharacterSkills::RefreshBatch.find_for(params[:id].to_s, user: current_user)
        render json: { error: 'not_found', message: 'This refresh no longer exists.' }, status: :not_found unless @refresh
      end

      def boolean_param(key)
        ActiveModel::Type::Boolean.new.cast(params[key]) || false
      end

      def render_error(code, message)
        render json: { error: code, message: message }, status: :unprocessable_entity
      end
    end
  end
end
