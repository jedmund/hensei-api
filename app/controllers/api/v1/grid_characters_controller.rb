# frozen_string_literal: true

module Api
  module V1
    ##
    # Controller handling API requests related to grid characters within a party.
    #
    # This controller provides endpoints for creating, updating, resolving conflicts,
    # updating uncap levels, and deleting grid characters. It follows the structure of
    # GridSummonsController and GridWeaponsController by using the new authorization method
    # `authorize_party_edit!` and deprecating legacy methods such as `set` in favor of
    # `find_party`, `find_grid_character`, and `find_incoming_character`.
    #
    # @see Api::V1::ApiController for shared API behavior.
    class GridCharactersController < Api::V1::ApiController
      include IdResolvable
      include CollectionSourceConcern
      include PartyAuthorizationConcern

      before_action :find_grid_character, only: %i[update update_uncap_level update_position destroy resolve sync sync_to_collection switch_style]
      before_action :find_party, only: %i[create resolve update update_uncap_level update_position swap destroy sync sync_to_collection switch_style]
      before_action :find_incoming_character, only: :create
      before_action :authorize_party_edit!, only: %i[create resolve update update_uncap_level update_position swap destroy sync sync_to_collection switch_style]

      ##
      # Creates a new grid character.
      #
      # If a conflicting grid character is found (i.e. one with the same character_id already exists
      # in the party), a conflict view is rendered so the user can decide on removal. Otherwise,
      # any grid character occupying the desired position is removed and a new one is created.
      #
      # @return [void]
      def create
        processed_params = transform_character_params(character_params)

        # Validate collection source constraint before proceeding
        if character_params[:collection_character_id].present?
          collection_item = CollectionCharacter.find_by(id: character_params[:collection_character_id])
          return unless validate_collection_source!(@party, collection_item)
        end

        if conflict_characters.present?
          render json: render_conflict_view(conflict_characters, @incoming_character, character_params[:position])
        else
          # Remove any existing grid character occupying the specified position.
          if (existing = GridCharacter.find_by(party_id: @party.id, position: character_params[:position]))
            existing.destroy
          end

          # Build the new grid character
          grid_character = build_new_grid_character(processed_params)

          if grid_character.save
            @party.mark_updated!
            grid_character.sync_from_collection! if grid_character.collection_character_id.present?
            grid_character.reload
            render json: GridCharacterBlueprint.render(grid_character,
                                                       root: :grid_character,
                                                       view: :full), status: :created
          else
            render_validation_error_response(grid_character)
          end
        end
      end

      ##
      # Updates an existing grid character.
      #
      # Assigns new rings and awakening data to their respective virtual attributes and updates other
      # permitted attributes. On success, the updated grid character view is rendered.
      #
      # @return [void]
      def update
        processed_params = transform_character_params(character_params)
        assign_raw_attributes(@grid_character)
        assign_transformed_attributes(@grid_character, processed_params)

        if @grid_character.save
          render json: GridCharacterBlueprint.render(@grid_character,
                                                     root: :grid_character,
                                                     view: :nested)
        else
          render_validation_error_response(@grid_character)
        end
      end

      ##
      # Updates the uncap level and transcendence step of a grid character.
      #
      # The grid character's uncap level and transcendence step are updated based on the provided parameters.
      # This action requires that the current user is authorized to modify the party.
      #
      # @return [void]
      def update_uncap_level
        @grid_character.uncap_level = character_params[:uncap_level]
        @grid_character.transcendence_step = [character_params[:transcendence_step].to_i, 5].min

        if @grid_character.save
          render json: GridCharacterBlueprint.render(@grid_character,
                                                     root: :grid_character,
                                                     view: :uncap)
        else
          render_validation_error_response(@grid_character)
        end
      end

      ##
      # Updates the position of a GridCharacter.
      #
      # Moves a grid character to a new position, maintaining sequential filling for main slots.
      # Validates that the target position is empty and within allowed bounds.
      #
      # @return [void]
      def update_position
        new_position = position_params[:position].to_i
        new_container = position_params[:container]

        # Validate position bounds (0-4 main, 5-6 extra)
        unless valid_character_position?(new_position)
          return render_unprocessable_entity_response(
            Api::V1::InvalidPositionError.new("Invalid position #{new_position} for character")
          )
        end

        # Check if target position is occupied
        if GridCharacter.exists?(party_id: @party.id, position: new_position)
          return render_unprocessable_entity_response(
            Api::V1::PositionOccupiedError.new("Position #{new_position} is already occupied")
          )
        end

        old_position = @grid_character.position
        @grid_character.position = new_position

        if @grid_character.save
          @party.mark_updated!
          # Compact positions after save so the moved character is no longer
          # included in the main positions query
          reordered = compact_character_positions if should_compact_characters?(old_position, new_position)

          render json: {
            party: PartyBlueprint.render_as_hash(@party.reload, view: :full),
            grid_character: GridCharacterBlueprint.render_as_hash(@grid_character.reload, view: :nested),
            reordered: reordered || false
          }, status: :ok
        else
          render_validation_error_response(@grid_character)
        end
      end

      ##
      # Swaps positions between two GridCharacters.
      #
      # Exchanges the positions of two grid characters within the same party.
      # Both characters must belong to the same party.
      #
      # @return [void]
      def swap
        source_id = swap_params[:source_id]
        target_id = swap_params[:target_id]

        source = GridCharacter.find_by(id: source_id, party_id: @party.id)
        target = GridCharacter.find_by(id: target_id, party_id: @party.id)

        unless source && target
          return render_not_found_response('grid_character')
        end

        # Perform the swap
        ActiveRecord::Base.transaction do
          temp_position = -999
          source_pos = source.position
          target_pos = target.position

          source.update!(position: temp_position)
          target.update!(position: source_pos)
          source.update!(position: target_pos)
        end

        @party.mark_updated!

        render json: {
          party: PartyBlueprint.render_as_hash(@party.reload, view: :full),
          swapped: {
            source: GridCharacterBlueprint.render_as_hash(source.reload, view: :nested),
            target: GridCharacterBlueprint.render_as_hash(target.reload, view: :nested)
          }
        }, status: :ok
      rescue ActiveRecord::RecordInvalid => e
        render_validation_error_response(e.record)
      end

      ##
      # Resolves conflicts for grid characters.
      #
      # This action destroys any conflicting grid characters as well as any grid character occupying
      # the target position, then creates a new grid character using a computed default uncap level.
      # The default uncap level is determined by the incoming character's attributes.
      #
      # @return [void]
      def resolve
        incoming = find_by_any_id(Character, resolve_params[:incoming])
        render_not_found_response('character') and return unless incoming

        conflicting = resolve_params[:conflicting].map { |id| GridCharacter.find_by(id: id) }.compact
        conflicting.each(&:destroy)

        if (existing = GridCharacter.find_by(party_id: @party.id, position: resolve_params[:position]))
          existing.destroy
        end

        grid_character = GridCharacter.create!(
          party_id: @party.id,
          character_id: incoming.id,
          position: resolve_params[:position],
          uncap_level: compute_max_uncap_level(incoming),
          transcendence_step: compute_max_transcendence_step(incoming)
        )
        @party.mark_updated!
        render json: GridCharacterBlueprint.render(grid_character,
                                                   root: :grid_character,
                                                   view: :nested), status: :created
      end

      ##
      # Destroys a grid character.
      #
      # If the current user is not the owner of the party, an unauthorized response is rendered.
      # On successful destruction, the destroyed grid character view is rendered.
      #
      # @return [void]
      def destroy
        grid_character = GridCharacter.find_by('id = ?', params[:id])

        return render_not_found_response('grid_character') if grid_character.nil?

        if grid_character.destroy
          @party.mark_updated!
          clear_collection_source_if_empty!(@party)
          render json: GridCharacterBlueprint.render(grid_character, view: :destroyed)
        else
          render_unprocessable_entity_response(
            Api::V1::GranblueError.new(grid_character.errors.full_messages.join(', '))
          )
        end
      end

      ##
      # Syncs a grid character from its linked collection character.
      #
      # Copies all customizations from the collection character to this grid character.
      # Returns 422 if no collection character is linked.
      #
      # @return [void]
      def sync
        unless @grid_character.collection_character.present?
          return render_unprocessable_entity_response(
            Api::V1::GranblueError.new('No collection character linked')
          )
        end

        @grid_character.sync_from_collection!
        render json: GridCharacterBlueprint.render(@grid_character.reload,
                                                   root: :grid_character,
                                                   view: :nested)
      end

      ##
      # Syncs a grid character to its linked collection character.
      #
      # Copies all customizations from this grid character to the collection character.
      # Returns 422 if no collection character is linked.
      #
      # @return [void]
      def sync_to_collection
        unless @grid_character.collection_character.present?
          return render_unprocessable_entity_response(
            Api::V1::GranblueError.new('No collection character linked')
          )
        end

        unless current_user.present? && @party.collection_source_user_id == current_user.id
          return render_unauthorized_response
        end

        @grid_character.sync_to_collection!
        render json: GridCharacterBlueprint.render(@grid_character.reload,
                                                   root: :grid_character,
                                                   view: :nested)
      end

      ##
      # Switches a grid character between its base and style swap variant.
      #
      # Finds the alternate character with the same granblue_id but opposite style_swap flag,
      # then updates the grid character's character_id to the alternate.
      #
      # @return [void]
      def switch_style
        current_character = @grid_character.character

        alternate = if current_character.style_swap?
                      current_character.base_character
                    else
                      current_character.style_swaps.first
                    end

        unless alternate
          return render_unprocessable_entity_response(
            Api::V1::GranblueError.new('No style swap variant found')
          )
        end

        @grid_character.update!(character_id: alternate.id)
        @party.mark_updated!
        render json: GridCharacterBlueprint.render(@grid_character.reload,
                                                   root: :grid_character,
                                                   view: :nested)
      end

      private

      ##
      # Builds a new grid character using the transformed parameters.
      #
      # @param processed_params [Hash] the transformed parameters.
      # @return [GridCharacter] the newly built grid character.
      def build_new_grid_character(processed_params)
        grid_character = GridCharacter.new(
          character_params.except(:rings, :awakening).merge(
            party_id: @party.id,
            character_id: @incoming_character.id,
            uncap_level: compute_max_uncap_level(@incoming_character),
            transcendence_step: compute_max_transcendence_step(@incoming_character)
          )
        )
        assign_transformed_attributes(grid_character, processed_params)
        assign_raw_attributes(grid_character)
        grid_character
      end

      ##
      # Computes the maximum uncap level for a character based on its flags.
      #
      # Special characters (limited/seasonal) have a different uncap progression:
      # - Base: 3, FLB: 4, Transcendence: 5
      # Regular characters:
      # - Base: 4, FLB: 5, Transcendence: 6
      #
      # @param character [Character] the character to compute max uncap for.
      # @return [Integer] the maximum uncap level.
      def compute_max_transcendence_step(character)
        character.transcendence ? 5 : 0
      end

      def compute_max_uncap_level(character)
        if character.special
          character.transcendence ? 5 : character.flb ? 4 : 3
        else
          character.transcendence ? 6 : character.flb ? 5 : 4
        end
      end

      ##
      # Assigns raw attributes from the original parameters to the grid character.
      #
      # These attributes (like new_rings and new_awakening) are used by model callbacks.
      # Note: We exclude :character_id and :party_id because they are already set correctly
      # in build_new_grid_character using the resolved UUIDs, not the raw granblue_id from params.
      #
      # @param grid_character [GridCharacter] the grid character instance.
      # @return [void]
      def assign_raw_attributes(grid_character)
        grid_character.new_rings = character_params[:rings] if character_params[:rings].present?
        grid_character.new_awakening = character_params[:awakening] if character_params[:awakening].present?
        grid_character.assign_attributes(character_params.except(:rings, :awakening, :character_id, :party_id))
      end

      ##
      # Assigns transformed attributes (such as uncap_level, transcendence_step, etc.) to the grid character.
      #
      # @param grid_character [GridCharacter] the grid character instance.
      # @param processed_params [Hash] the transformed parameters.
      # @return [void]
      def assign_transformed_attributes(grid_character, processed_params)
        grid_character.uncap_level = processed_params[:uncap_level] if processed_params[:uncap_level]
        grid_character.transcendence_step = processed_params[:transcendence_step] if processed_params[:transcendence_step]
        grid_character.perpetuity = processed_params[:perpetuity] if processed_params.key?(:perpetuity)
        grid_character.earring = processed_params[:earring] if processed_params[:earring]

        return unless processed_params[:awakening_id]

        grid_character.awakening_id = processed_params[:awakening_id]
        grid_character.awakening_level = processed_params[:awakening_level]
      end

      ##
      # Transforms the incoming character parameters to the required format.
      #
      # The frontend sends parameters in a raw format that need to be processed (e.g., converting string
      # values to integers, handling nested attributes for rings and awakening). This method extracts and
      # converts only the keys that were provided.
      #
      # @param raw_params [ActionController::Parameters] the raw permitted parameters.
      # @return [Hash] the transformed parameters.
      def transform_character_params(raw_params)
        # Convert to a symbolized hash for convenience.
        raw = raw_params.to_h.deep_symbolize_keys

        # Only update keys that were provided.
        transformed = raw.slice(:uncap_level, :transcendence_step, :perpetuity)
        transformed[:uncap_level] = raw[:uncap_level] if raw[:uncap_level].present?
        transformed[:transcendence_step] = raw[:transcendence_step] if raw[:transcendence_step].present?

        # Process rings if provided.
        transformed.merge!(transform_rings(raw[:rings])) if raw[:rings].present?

        # Process earring if provided.
        transformed[:earring] = raw[:earring] if raw[:earring].present?

        # Process awakening if provided.
        if raw[:awakening].present?
          transformed[:awakening_id] = raw[:awakening][:id]
          # Default to 1 if level is missing (to satisfy validations)
          transformed[:awakening_level] = raw[:awakening][:level].present? ? raw[:awakening][:level] : 1
        end

        transformed
      end

      ##
      # Transforms the rings data to ensure exactly four rings are present.
      #
      # Pads the array with a default ring hash if necessary.
      #
      # @param rings [Array, Hash] the rings data from the frontend.
      # @return [Hash] a hash with keys :ring1, :ring2, :ring3, :ring4.
      def transform_rings(rings)
        default_ring = { modifier: nil, strength: nil }
        # Ensure rings is an array of hashes.
        rings_array = Array(rings).map(&:to_h)
        # Pad the array to exactly four rings if needed.
        rings_array.fill(default_ring, rings_array.size...4)
        {
          ring1: rings_array[0],
          ring2: rings_array[1],
          ring3: rings_array[2],
          ring4: rings_array[3]
        }
      end

      ##
      # Returns any grid characters in the party that conflict with the incoming character.
      #
      # Conflict is detected by comparing the integer `character_id` arrays on the Character records.
      # Characters that share any overlapping IDs in their `character_id` arrays are considered
      # variants of the same base character and cannot coexist in a party.
      #
      # @return [Array<GridCharacter>]
      def conflict_characters
        incoming_ids = @incoming_character.character_id
        return [] if incoming_ids.blank?

        @party.characters.includes(:character).select do |gc|
          gc.character.character_id.intersect?(incoming_ids)
        end
      end

      ##
      # Renders the conflict view for characters.
      #
      # @param conflict_characters [Array<GridCharacter>] the conflicting grid characters.
      # @param incoming_character [Character] the incoming character.
      # @param incoming_position [Integer] the desired position.
      # @return [String] the rendered conflict view.
      def render_conflict_view(conflict_characters, incoming_character, incoming_position)
        ConflictBlueprint.render(nil,
                                 view: :characters,
                                 conflict_characters: conflict_characters,
                                 incoming_character: incoming_character,
                                 incoming_position: incoming_position)
      end

      ##
      # Finds and sets the party based on parameters.
      #
      # Checks for the party id in params[:character][:party_id], params[:party_id], or falls back to the party
      # associated with the current grid character. Renders a not found response if the party is missing.
      #
      # @return [void]
      def find_party
        @party = Party.find_by(id: params.dig(:character, :party_id)) ||
          Party.find_by(id: params[:party_id]) ||
          @grid_character&.party
        render_not_found_response('party') unless @party
      end

      ##
      # Finds and sets the grid character based on the provided parameters.
      #
      # Searches for a grid character by its ID and renders a not found response if it is absent.
      #
      # @return [void]
      def find_grid_character
        grid_character_id = params[:id] || params.dig(:character, :id) || params.dig(:resolve, :conflicting)
        @grid_character = GridCharacter.includes(:awakening).find_by(id: grid_character_id)
        render_not_found_response('grid_character') unless @grid_character
      end

      ##
      # Finds and sets the incoming character based on the provided parameters.
      #
      # Searches for a character using the :character_id parameter and renders a not found response if it is absent.
      #
      # @return [void]
      def find_incoming_character
        character_id = character_params[:character_id]
        @incoming_character = find_by_any_id(Character, character_id)

        unless @incoming_character
          render_unprocessable_entity_response(Api::V1::NoCharacterProvidedError.new)
        end
      end

      ##
      # Validates if a character position is valid.
      #
      # @param position [Integer] the position to validate.
      # @return [Boolean] true if the position is valid; false otherwise.
      def valid_character_position?(position)
        # Main slots (0-4), extra slots (5-7) for unlimited raids
        (0..7).cover?(position)
      end

      ##
      # Determines if character positions should be compacted.
      #
      # @param old_position [Integer] the old position.
      # @param new_position [Integer] the new position.
      # @return [Boolean] true if compaction is needed; false otherwise.
      def should_compact_characters?(old_position, new_position)
        # Compact if moving from main slots (0-4) to extra (5-7) or vice versa
        main_to_extra = (0..4).cover?(old_position) && (5..7).cover?(new_position)
        extra_to_main = (5..7).cover?(old_position) && (0..4).cover?(new_position)
        main_to_extra || extra_to_main
      end

      ##
      # Compacts character positions to maintain sequential filling.
      #
      # @return [Boolean] true if positions were reordered; false otherwise.
      def compact_character_positions
        main_characters = @party.characters.where(position: 0..4).order(:position)

        ActiveRecord::Base.transaction do
          main_characters.each_with_index do |char, index|
            char.update!(position: index) if char.position != index
          end
        end

        true
      end

      ##
      # Specifies and permits the allowed character parameters.
      #
      # @return [ActionController::Parameters] the permitted parameters.
      def character_params
        params.require(:character).permit(
          :id,
          :party_id,
          :character_id,
          :collection_character_id,
          :position,
          :uncap_level,
          :transcendence_step,
          :perpetuity,
          awakening: %i[id level],
          rings: %i[modifier strength],
          earring: %i[modifier strength]
        )
      end

      ##
      # Specifies and permits the position update parameters.
      #
      # @return [ActionController::Parameters] the permitted parameters.
      def position_params
        params.permit(:position, :container)
      end

      ##
      # Specifies and permits the swap parameters.
      #
      # @return [ActionController::Parameters] the permitted parameters.
      def swap_params
        params.permit(:source_id, :target_id)
      end

      ##
      # Specifies and permits the allowed resolve parameters.
      #
      # @return [ActionController::Parameters] the permitted parameters.
      def resolve_params
        params.require(:resolve).permit(:position, :incoming, conflicting: [])
      end
    end
  end
end
