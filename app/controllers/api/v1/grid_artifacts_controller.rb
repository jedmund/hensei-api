# frozen_string_literal: true

module Api
  module V1
    class GridArtifactsController < Api::V1::ApiController
      before_action :find_grid_artifact, only: %i[update destroy]
      before_action :find_party, only: %i[create update destroy]
      before_action :find_grid_character, only: %i[create]
      before_action :find_artifact, only: %i[create]
      before_action :authorize_party_edit!, only: %i[create update destroy]

      # POST /grid_artifacts
      def create
        # Check if grid_character already has an artifact
        if @grid_character.grid_artifact.present?
          @grid_character.grid_artifact.destroy
        end

        @grid_artifact = GridArtifact.new(
          grid_artifact_params.merge(
            grid_character_id: @grid_character.id,
            artifact_id: @artifact.id
          )
        )

        if @grid_artifact.save
          render json: GridArtifactBlueprint.render(@grid_artifact, view: :nested, root: :grid_artifact), status: :created
        else
          render_validation_error_response(@grid_artifact)
        end
      end

      # PATCH/PUT /grid_artifacts/:id
      def update
        if @grid_artifact.update(grid_artifact_params)
          render json: GridArtifactBlueprint.render(@grid_artifact, view: :nested, root: :grid_artifact), status: :ok
        else
          render_validation_error_response(@grid_artifact)
        end
      end

      # DELETE /grid_artifacts/:id
      def destroy
        if @grid_artifact.destroy
          render json: GridArtifactBlueprint.render(@grid_artifact, view: :destroyed), status: :ok
        else
          render_unprocessable_entity_response(
            Api::V1::GranblueError.new(@grid_artifact.errors.full_messages.join(', '))
          )
        end
      end

      private

      def find_grid_artifact
        @grid_artifact = GridArtifact.find_by(id: params[:id])
        render_not_found_response('grid_artifact') unless @grid_artifact
      end

      def find_party
        @party = if @grid_artifact
                   @grid_artifact.grid_character.party
                 else
                   Party.find_by(id: params[:party_id])
                 end
        render_not_found_response('party') unless @party
      end

      def find_grid_character
        @grid_character = GridCharacter.find_by(id: params.dig(:grid_artifact, :grid_character_id))
        render_not_found_response('grid_character') unless @grid_character
      end

      def find_artifact
        artifact_id = params.dig(:grid_artifact, :artifact_id)
        @artifact = Artifact.find_by(id: artifact_id)
        render_not_found_response('artifact') unless @artifact
      end

      def authorize_party_edit!
        if @party.user.present?
          authorize_user_party
        else
          authorize_anonymous_party
        end
      end

      def authorize_user_party
        return if current_user.present? && @party.user == current_user

        render_unauthorized_response
      end

      def authorize_anonymous_party
        provided_edit_key = edit_key.to_s.strip.force_encoding('UTF-8')
        party_edit_key = @party.edit_key.to_s.strip.force_encoding('UTF-8')
        return if valid_edit_key?(provided_edit_key, party_edit_key)

        render_unauthorized_response
      end

      def valid_edit_key?(provided_edit_key, party_edit_key)
        provided_edit_key.present? &&
          provided_edit_key.bytesize == party_edit_key.bytesize &&
          ActiveSupport::SecurityUtils.secure_compare(provided_edit_key, party_edit_key)
      end

      def grid_artifact_params
        params.require(:grid_artifact).permit(
          :grid_character_id, :artifact_id, :element, :proficiency, :level,
          skill1: %i[modifier strength level],
          skill2: %i[modifier strength level],
          skill3: %i[modifier strength level],
          skill4: %i[modifier strength level]
        )
      end
    end
  end
end
