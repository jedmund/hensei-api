# frozen_string_literal: true

module Api
  module V1
    ##
    # Controller handling API requests related to grid characters within a party.
    #
    # This controller provides endpoints for creating, updating and resolving conflicts
    # between grid characters, and for switching a character's style. Moving, swapping,
    # uncapping, removing and collection sync come from GridItemActions.
    #
    # @see Api::V1::ApiController for shared API behavior.
    class GridCharactersController < Api::V1::ApiController
      include IdResolvable
      include CollectionSourceConcern
      include PartyAuthorizationConcern
      include SubstituteGridPreloading
      include PartyFullLoading
      include GridItemActions

      grid_item GridCharacter, blueprint: GridCharacterBlueprint, view: :nested,
                               positions: 0..7, party_param_keys: %i[character resolve]

      before_action :find_grid_item, only: GridItemActions::ROW_ACTIONS + %i[switch_style]
      before_action :find_party, only: GridItemActions::EDIT_ACTIONS + %i[resolve switch_style]
      before_action :find_incoming_character, only: :create
      before_action :authorize_party_edit!, only: GridItemActions::EDIT_ACTIONS + %i[resolve switch_style]

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
            # Re-fetch with blueprint preloads so the :full render avoids N+1s.
            grid_character = GridCharacter.includes(*GridCharacter::NESTED_BLUEPRINT_PRELOADS, :substitutions)
                                          .find(grid_character.id)
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
        if character_params[:collection_character_id].present?
          collection_item = CollectionCharacter.find_by(id: character_params[:collection_character_id])
          return unless validate_collection_source!(@party, collection_item)
        end

        processed_params = transform_character_params(character_params)
        assign_raw_attributes(@grid_item)
        assign_transformed_attributes(@grid_item, processed_params)

        if @grid_item.save
          render json: GridCharacterBlueprint.render(@grid_item,
                                                     root: :grid_character,
                                                     view: :nested)
        else
          render_validation_error_response(@grid_item)
        end
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

        # Every conflicting id must be a grid character in the target party.
        conflicting_ids = Array(resolve_params[:conflicting]).compact_blank.map(&:to_s).uniq
        conflicting = GridCharacter.where(id: conflicting_ids, party_id: @party.id).to_a
        render_not_found_response('grid_character') and return if conflicting_ids.empty? || conflicting.size != conflicting_ids.size

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
      # Switches a grid character between its base and style swap variant.
      #
      # Finds the alternate character with the same granblue_id but opposite style_swap flag,
      # then updates the grid character's character_id to the alternate.
      #
      # @return [void]
      def switch_style
        current_character = @grid_item.character

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

        @grid_item.update!(character_id: alternate.id)
        @party.mark_updated!
        render json: GridCharacterBlueprint.render(@grid_item.reload,
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
      # Characters know their own caps: special characters run Base 3, FLB 4,
      # ULB 5; regular ones Base 4, FLB 5, Transcendence 6.
      #
      # @param character [Character] the character to compute max uncap for.
      # @return [Integer] the maximum uncap level.
      def compute_max_uncap_level(character)
        character.max_uncap_level
      end

      def compute_max_transcendence_step(character)
        character.max_transcendence_stage
      end

      ##
      # Takes the requested uncap level and transcendence step as sent.
      #
      # @return [void]
      def apply_uncap_level
        @grid_item.uncap_level = character_params[:uncap_level]
        @grid_item.transcendence_step = character_params[:transcendence_step].to_i
      end

      # Moving between the main and extra slots closes the gap in the main slots.
      def after_position_save(old_position, new_position)
        reordered = compact_character_positions if should_compact_characters?(old_position, new_position)
        { reordered: reordered || false }
      end

      ##
      # Assigns raw attributes from the original parameters to the grid character.
      #
      # These attributes (like new_rings and new_awakening) are used by model callbacks.
      # Note: We exclude :character_id because it is already set correctly in
      # build_new_grid_character using the resolved UUID, not the raw granblue_id from params.
      #
      # @param grid_character [GridCharacter] the grid character instance.
      # @return [void]
      def assign_raw_attributes(grid_character)
        grid_character.new_rings = character_params[:rings] if character_params[:rings].present?
        grid_character.new_awakening = character_params[:awakening] if character_params[:awakening].present?
        # `role_ids` is the public param name; map it to the Rails-generated
        # `grid_character_role_ids=` setter on the has_many :through association.
        # Reset the through-association cache so the blueprint sees the new set
        # (the cache was warmed by `find_grid_item`'s preload).
        if character_params.key?(:role_ids)
          grid_character.grid_character_role_ids = Array(character_params[:role_ids])
          grid_character.grid_character_roles.reset
        end
        grid_character.assign_attributes(
          character_params.except(:rings, :awakening, :character_id, :role_ids)
        )
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
          transformed[:awakening_level] = raw[:awakening][:level].presence || 1
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
      # Finds and sets the incoming character based on the provided parameters.
      #
      # Searches for a character using the :character_id parameter and renders a not found response if it is absent.
      #
      # @return [void]
      def find_incoming_character
        character_id = character_params[:character_id]
        @incoming_character = find_by_any_id(Character, character_id)

        return if @incoming_character

        render_unprocessable_entity_response(Api::V1::NoCharacterProvidedError.new)
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
        grid_item_params(
          :id,
          :character_id,
          :collection_character_id,
          :position,
          :uncap_level,
          :transcendence_step,
          :perpetuity,
          :brought_by_blessing,
          role_ids: [],
          awakening: %i[id level],
          rings: %i[modifier strength],
          earring: %i[modifier strength],
          full_auto_skills: %w[0 1 2 3]
        )
      end

      ##
      # Specifies and permits the allowed resolve parameters.
      #
      # @return [ActionController::Parameters] the permitted parameters.
      def resolve_params
        params.expect(resolve: [:position, :incoming, { conflicting: [] }])
      end
    end
  end
end
