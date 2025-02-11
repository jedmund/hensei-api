# frozen_string_literal: true

module Api
  module V1
    ##
    # Controller handling API requests related to grid weapons within a party.
    #
    # This controller provides endpoints for creating, updating, resolving conflicts, and deleting grid weapons.
    # It ensures that the correct party and weapon are found and that the current user (or edit key) is authorized.
    #
    # @see Api::V1::ApiController for shared API behavior.
    class GridWeaponsController < Api::V1::ApiController
      before_action :find_grid_weapon, only: %i[update update_uncap_level resolve destroy]
      before_action :find_party, only: %i[create update update_uncap_level resolve destroy]
      before_action :find_incoming_weapon, only: %i[create resolve]
      before_action :authorize_party_edit!, only: %i[create update update_uncap_level resolve destroy]

      ##
      # Creates a new GridWeapon.
      #
      # Builds a new GridWeapon using parameters merged with the party and weapon IDs.
      # If the model validations (including compatibility and conflict validations)
      # pass, the weapon is saved; otherwise, conflict resolution is attempted.
      #
      # @return [void]
      def create
        return render_unprocessable_entity_response(Api::V1::NoWeaponProvidedError.new) if @incoming_weapon.nil?

        grid_weapon = GridWeapon.new(
          weapon_params.merge(
            party_id: @party.id,
            weapon_id: @incoming_weapon.id
          )
        )

        if grid_weapon.valid?
          save_weapon(grid_weapon)
        else
          if grid_weapon.errors[:series].include?('must not conflict with existing weapons')
            handle_conflict(grid_weapon)
          else
            render_validation_error_response(grid_weapon)
          end
        end
      end

      ##
      # Updates an existing GridWeapon.
      #
      # After checking authorization, assigns new attributes to the weapon.
      # Also normalizes modifier and strength fields, then renders the updated view on success.
      #
      # @return [void]
      def update
        normalize_ax_fields!
        if @grid_weapon.update(weapon_params)
          render json: GridWeaponBlueprint.render(@grid_weapon, view: :full, root: :grid_weapon), status: :ok
        else
          render_validation_error_response(@grid_weapon)
        end
      end

      ##
      # Updates the uncap level and transcendence step of a GridWeapon.
      #
      # Finds the weapon to update, computes the maximum allowed uncap level based on its associated
      # weapon’s flags, and then updates the fields accordingly.
      #
      # @return [void]
      def update_uncap_level
        max_uncap = compute_max_uncap_level(@grid_weapon.weapon)
        requested_uncap = weapon_params[:uncap_level].to_i
        new_uncap = requested_uncap > max_uncap ? max_uncap : requested_uncap

        if @grid_weapon.update(uncap_level: new_uncap, transcendence_step: weapon_params[:transcendence_step].to_i)
          render json: GridWeaponBlueprint.render(@grid_weapon, view: :full, root: :grid_weapon), status: :ok
        else
          render_validation_error_response(@grid_weapon)
        end
      end

      ##
      # Resolves conflicts by removing conflicting grid weapons and creating a new one.
      #
      # Expects resolve parameters that include the desired position, the incoming weapon ID,
      # and a list of conflicting GridWeapon IDs. After deleting conflicting records and any existing
      # grid weapon at that position, creates a new GridWeapon with computed uncap_level.
      #
      # @return [void]
      def resolve
        incoming = Weapon.find_by(id: resolve_params[:incoming])
        conflicting_ids = resolve_params[:conflicting]
        conflicting_weapons = GridWeapon.where(id: conflicting_ids)

        # Destroy each conflicting weapon
        conflicting_weapons.each(&:destroy)

        # Destroy the weapon at the desired position if it exists
        if (existing_weapon = GridWeapon.find_by(party_id: @party.id, position: resolve_params[:position]))
          existing_weapon.destroy
        end

        # Compute the default uncap level based on incoming weapon flags, maxing out at ULB.
        new_uncap = compute_default_uncap(incoming)
        grid_weapon = GridWeapon.create!(
          party_id: @party.id,
          weapon_id: incoming.id,
          position: resolve_params[:position],
          uncap_level: new_uncap,
          transcendence_step: 0
        )

        if grid_weapon.persisted?
          render json: GridWeaponBlueprint.render(grid_weapon, view: :full, root: :grid_weapon, meta: { replaced: resolve_params[:position] }), status: :created
        else
          render_validation_error_response(grid_weapon)
        end
      end

      ##
      # Destroys a GridWeapon.
      #
      # Checks authorization and, if allowed, destroys the weapon and renders the destroyed view.
      #
      # @return [void]
      def destroy
        grid_weapon = GridWeapon.find_by('id = ?', params[:id])

        return render_not_found_response('grid_weapon') if grid_weapon.nil?

        render json: GridWeaponBlueprint.render(grid_weapon, view: :destroyed), status: :ok if grid_weapon.destroy
      end

      private

      ##
      # Computes the maximum uncap level for a given weapon based on its flags.
      #
      # @param weapon [Weapon] the associated weapon.
      # @return [Integer] the maximum allowed uncap level.
      def compute_max_uncap_level(weapon)
        if weapon.flb && !weapon.ulb && !weapon.transcendence
          4
        elsif weapon.ulb && !weapon.transcendence
          5
        elsif weapon.transcendence
          6
        else
          3
        end
      end

      ##
      # Computes the default uncap level for an incoming weapon.
      #
      # This method calculates the default uncap level by computing the maximum uncap level based on the weapon's flags.
      #
      # @param incoming [Weapon] the incoming weapon.
      # @return [Integer] the default uncap level.
      def compute_default_uncap(incoming)
        compute_max_uncap_level(incoming)
      end

      ##
      # Normalizes the AX modifier fields for the weapon parameters.
      #
      # Sets ax_modifier1 and ax_modifier2 to nil if their integer values equal -1.
      #
      # @return [void]
      def normalize_ax_fields!
        params[:weapon][:ax_modifier1] = nil if weapon_params[:ax_modifier1].to_i == -1

        params[:weapon][:ax_modifier2] = nil if weapon_params[:ax_modifier2].to_i == -1
      end

      ##
      # Renders the grid weapon view.
      #
      # @param grid_weapon [GridWeapon] the grid weapon to render.
      # @param conflict_position [Integer] the position that was replaced.
      # @return [String] the rendered view.
      def render_grid_weapon_view(grid_weapon, conflict_position)
        GridWeaponBlueprint.render(grid_weapon,
                                   view: :full,
                                   root: :grid_weapon,
                                   meta: { replaced: conflict_position })
      end

      ##
      # Saves the GridWeapon.
      #
      # Deletes any existing grid weapon at the same position,
      # adjusts party attributes based on the weapon's position,
      # and renders the full view upon successful save.
      #
      # @param weapon [GridWeapon] the grid weapon to save.
      # @return [void]
      def save_weapon(weapon)
        # Check weapon validation and delete existing grid weapon if one already exists at position
        if (existing = GridWeapon.find_by(party_id: @party.id, position: weapon.position))
          existing.destroy
        end

        # Set the party's element if the grid weapon is being set as mainhand
        if weapon.position.to_i == -1
          @party.element = weapon.weapon.element
          @party.save!
        elsif GridWeapon::EXTRA_POSITIONS.include?(weapon.position.to_i)
          @party.extra = true
          @party.save!
        end

        if weapon.save
          output = GridWeaponBlueprint.render(weapon, view: :full, root: :grid_weapon)
          render json: output, status: :created
        else
          render_validation_error_response(weapon)
        end
      end

      ##
      # Handles conflicts when a new GridWeapon fails validation.
      #
      # Retrieves the array of conflicting grid weapons (via the model’s conflicts method)
      # and either renders a conflict view (if the canonical weapons differ) or updates the
      # conflicting grid weapon's position.
      #
      # @param weapon [GridWeapon] the weapon that failed validation.
      # @return [void]
      def handle_conflict(weapon)
        conflict_weapons = weapon.conflicts(party)
        # Find if one of the conflicting grid weapons is associated with the incoming weapon.
        conflict_weapon = conflict_weapons.find { |gw| gw.weapon.id == incoming_weapon.id }

        if conflict_weapon.nil?
          output = render_conflict_view(conflict_weapons, incoming_weapon, weapon_params[:position])
          render json: output
        else
          old_position = conflict_weapon.position
          conflict_weapon.position = weapon_params[:position]
          if conflict_weapon.save
            output = render_grid_weapon_view(conflict_weapon, old_position)
            render json: output
          else
            render_validation_error_response(conflict_weapon)
          end
        end
      end

      ##
      # Renders the conflict view.
      #
      # @param conflict_weapons [Array<GridWeapon>] an array of conflicting grid weapons.
      # @param incoming_weapon [Weapon] the incoming weapon.
      # @param incoming_position [Integer] the desired position.
      # @return [String] the rendered conflict view.
      def render_conflict_view(conflict_weapons, incoming_weapon, incoming_position)
        ConflictBlueprint.render(nil,
                                 view: :weapons,
                                 conflict_weapons: conflict_weapons,
                                 incoming_weapon: incoming_weapon,
                                 incoming_position: incoming_position)
      end

      ##
      # Finds and sets the GridWeapon based on the provided parameters.
      #
      # Searches for a grid weapon using various parameter keys and renders a not found response if it is absent.
      #
      # @return [void]
      def find_grid_weapon
        grid_weapon_id = params[:id] || params.dig(:weapon, :id) || params.dig(:resolve, :conflicting)
        @grid_weapon = GridWeapon.find_by(id: grid_weapon_id)
        render_not_found_response('grid_weapon') unless @grid_weapon
      end

      ##
      # Finds and sets the incoming weapon.
      #
      # @return [void]
      def find_incoming_weapon
        if params.dig(:weapon, :weapon_id).present?
          @incoming_weapon = Weapon.find_by(id: params.dig(:weapon, :weapon_id))
          render_not_found_response('weapon') unless @incoming_weapon
        else
          @incoming_weapon = nil
        end
      end

      ##
      # Finds and sets the party based on parameters.
      #
      # Renders an unauthorized response if the current user is not the owner.
      #
      # @return [void]
      def find_party
        @party = Party.find_by(id: params.dig(:weapon, :party_id)) || Party.find_by(id: params[:party_id]) || @grid_weapon&.party
        render_not_found_response('party') unless @party
      end

      ##
      # Authorizes the current action by ensuring that the current user or provided edit key matches the party's owner.
      #
      # For parties associated with a user, it verifies that the current_user is the owner.
      # For anonymous parties, it checks that the provided edit key matches the party's edit key.
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
      # Renders an unauthorized response unless the current user is present and
      # matches the party's user.
      #
      # @return [void]
      def authorize_user_party
        return if current_user.present? && @party.user == current_user

        return render_unauthorized_response
      end

      ##
      # Authorizes an action for an anonymous party using an edit key.
      #
      # Retrieves and normalizes the provided edit key and compares it with the party's edit key.
      # Renders an unauthorized response unless the keys are valid.
      #
      # @return [void]
      def authorize_anonymous_party
        provided_edit_key = edit_key.to_s.strip.force_encoding('UTF-8')
        party_edit_key = @party.edit_key.to_s.strip.force_encoding('UTF-8')
        return if valid_edit_key?(provided_edit_key, party_edit_key)

        return render_unauthorized_response
      end

      ##
      # Validates that the provided edit key matches the party's edit key.
      #
      # @param provided_edit_key [String] the edit key provided in the request.
      # @param party_edit_key [String] the edit key associated with the party.
      # @return [Boolean] true if the edit keys match; false otherwise.
      def valid_edit_key?(provided_edit_key, party_edit_key)
        provided_edit_key.present? &&
          provided_edit_key.bytesize == party_edit_key.bytesize &&
          ActiveSupport::SecurityUtils.secure_compare(provided_edit_key, party_edit_key)
      end

      ##
      # Specifies and permits the allowed weapon parameters.
      #
      # @return [ActionController::Parameters] the permitted parameters.
      def weapon_params
        params.require(:weapon).permit(
          :id, :party_id, :weapon_id,
          :position, :mainhand, :uncap_level, :transcendence_step, :element,
          :weapon_key1_id, :weapon_key2_id, :weapon_key3_id,
          :ax_modifier1, :ax_modifier2, :ax_strength1, :ax_strength2,
          :awakening_id, :awakening_level
        )
      end

      ##
      # Specifies and permits the resolve parameters.
      #
      # @return [ActionController::Parameters] the permitted parameters.
      def resolve_params
        params.require(:resolve).permit(:position, :incoming, conflicting: [])
      end
    end
  end
end
