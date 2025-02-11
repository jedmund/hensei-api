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
      before_action :find_grid_character, only: %i[update update_uncap_level destroy resolve]
      before_action :find_party, only: %i[create resolve update update_uncap_level destroy]
      before_action :find_incoming_character, only: :create
      before_action :authorize_party_edit!, only: %i[create resolve update update_uncap_level destroy]

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
            render json: GridCharacterBlueprint.render(grid_character,
                                                       root: :grid_character,
                                                       view: :nested), status: :created
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
          ap "you are Here"
          ap @grid_character.errors
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
        @grid_character.transcendence_step = character_params[:transcendence_step]

        if @grid_character.save
          render json: GridCharacterBlueprint.render(@grid_character,
                                                     root: :grid_character,
                                                     view: :nested)
        else
          render_validation_error_response(@grid_character)
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
        incoming = Character.find_by(id: resolve_params[:incoming])
        render_not_found_response('character') and return unless incoming

        conflicting = resolve_params[:conflicting].map { |id| GridCharacter.find_by(id: id) }.compact
        conflicting.each(&:destroy)

        if (existing = GridCharacter.find_by(party_id: @party.id, position: resolve_params[:position]))
          existing.destroy
        end

        # Compute the default uncap level based on the incoming character's flags.
        if incoming.special
          uncap_level = 3
          uncap_level = 5 if incoming.ulb
          uncap_level = 4 if incoming.flb
        else
          uncap_level = 4
          uncap_level = 6 if incoming.ulb
          uncap_level = 5 if incoming.flb
        end

        grid_character = GridCharacter.create!(
          party_id: @party.id,
          character_id: incoming.id,
          position: resolve_params[:position],
          uncap_level: uncap_level
        )
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

        render json: GridCharacterBlueprint.render(grid_character, view: :destroyed) if grid_character.destroy
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
            character_id: @incoming_character.id
          )
        )
        assign_transformed_attributes(grid_character, processed_params)
        assign_raw_attributes(grid_character)
        grid_character
      end

      ##
      # Assigns raw attributes from the original parameters to the grid character.
      #
      # These attributes (like new_rings and new_awakening) are used by model callbacks.
      #
      # @param grid_character [GridCharacter] the grid character instance.
      # @return [void]
      def assign_raw_attributes(grid_character)
        grid_character.new_rings = character_params[:rings] if character_params[:rings].present?
        grid_character.new_awakening = character_params[:awakening] if character_params[:awakening].present?
        grid_character.assign_attributes(character_params.except(:rings, :awakening))
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
      # Conflict is defined as any grid character already in the party with the same character_id as the
      # incoming character. This method is used to prompt the user for conflict resolution.
      #
      # @return [Array<GridCharacter>]
      def conflict_characters
        @party.characters.where(character_id: @incoming_character.id).to_a
      end

      def find_conflict_characters(incoming_character)
        # Check all character ids on incoming character against current characters
        conflict_ids = (current_characters & incoming_character.character_id)

        return unless conflict_ids.length.positive?

        # Find conflicting character ids in party characters
        party.characters.filter do |c|
          c if (conflict_ids & c.character.character_id).length.positive?
        end.flatten
      end

      def find_current_characters
        # Make a list of all character IDs
        @current_characters = party.characters.map do |c|
          Character.find(c.character.id).character_id
        end.flatten
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
        @incoming_character = Character.find_by(id: character_params[:character_id])
        render_unprocessable_entity_response(Api::V1::NoCharacterProvidedError.new) unless @incoming_character
      end

      ##
      # Authorizes the current action by ensuring that the current user or provided edit key
      # matches the party's owner.
      #
      # For parties associated with a user, it verifies that the current user is the owner.
      # For anonymous parties, it compares the provided edit key with the party's edit key.
      #
      # @return [void]
      def authorize_party_edit!
        if @party.user.present?
          authorize_user_party
        else
          authorize_anonymous_party
        end
      end

      ##
      # Authorizes an action for a party that belongs to a user.
      #
      # Renders an unauthorized response unless the current user is present and matches the party's user.
      #
      # @return [void]
      def authorize_user_party
        return if current_user.present? && @party.user == current_user

        render_unauthorized_response
      end

      ##
      # Authorizes an action for an anonymous party using an edit key.
      #
      # Compares the provided edit key with the party's edit key and renders an unauthorized response
      # if they do not match.
      #
      # @return [void]
      def authorize_anonymous_party
        provided_edit_key = edit_key.to_s.strip.force_encoding('UTF-8')
        party_edit_key = @party.edit_key.to_s.strip.force_encoding('UTF-8')
        return if valid_edit_key?(provided_edit_key, party_edit_key)

        render_unauthorized_response
      end

      ##
      # Validates that the provided edit key matches the party's edit key.
      #
      # @param provided_edit_key [String] the edit key provided in the request.
      # @param party_edit_key [String] the edit key associated with the party.
      # @return [Boolean] true if the keys match; false otherwise.
      def valid_edit_key?(provided_edit_key, party_edit_key)
        provided_edit_key.present? &&
          provided_edit_key.bytesize == party_edit_key.bytesize &&
          ActiveSupport::SecurityUtils.secure_compare(provided_edit_key, party_edit_key)
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
      # Specifies and permits the allowed resolve parameters.
      #
      # @return [ActionController::Parameters] the permitted parameters.
      def resolve_params
        params.require(:resolve).permit(:position, :incoming, conflicting: [])
      end
    end
  end
end
