# frozen_string_literal: true

module Api
  module V1
    class GridArtifactsController < Api::V1::ApiController
      include PartyAuthorizationConcern
      include CollectionSourceConcern

      before_action :find_grid_artifact, only: %i[update destroy sync]
      before_action :find_party, only: %i[create update destroy sync]
      before_action :authorize_party_edit!, only: %i[create update destroy sync]
      before_action :find_grid_character, only: %i[create]
      before_action :find_artifact, only: %i[create]

      # POST /grid_artifacts
      def create
        return unless validate_collection_access!(collection_artifact_param)

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
        return unless validate_collection_access!(collection_artifact_param)

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

      # POST /grid_artifacts/:id/sync
      def sync
        unless @grid_artifact.collection_artifact.present?
          return render_unprocessable_entity_response(
            Api::V1::GranblueError.new('No collection artifact linked')
          )
        end

        return unless validate_collection_access!(@grid_artifact.collection_artifact)

        @grid_artifact.sync_from_collection!
        render json: GridArtifactBlueprint.render(@grid_artifact.reload,
                                                  root: :grid_artifact,
                                                  view: :nested)
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
        # The grid character must belong to the party being edited; a foreign
        # id is treated as not found (the party always comes from the request
        # here, so it can't vouch for a character from another party).
        @grid_character = @party.all_characters.find_by(id: params.dig(:grid_artifact, :grid_character_id))
        render_not_found_response('grid_character') unless @grid_character
      end

      def find_artifact
        artifact_id = params.dig(:grid_artifact, :artifact_id)
        @artifact = Artifact.find_by(id: artifact_id)
        render_not_found_response('artifact') unless @artifact
      end

      # The collection item a create/update wants to link, or nil.
      def collection_artifact_param
        id = grid_artifact_params[:collection_artifact_id]
        CollectionArtifact.find_by(id: id) if id.present?
      end

      # A grid artifact belongs to its grid character and its catalogue
      # artifact; both are resolved server-side on create (find_grid_character,
      # find_artifact) and must never change through update, so they're kept
      # out of the permit list (update would otherwise repoint the artifact at
      # any character id, including one in another user's party).
      def grid_artifact_params
        params.require(:grid_artifact).permit(
          :collection_artifact_id,
          :element, :proficiency, :level, :reroll_slot,
          skill1: %i[modifier quality level],
          skill2: %i[modifier quality level],
          skill3: %i[modifier quality level],
          skill4: %i[modifier quality level]
        )
      end
    end
  end
end
