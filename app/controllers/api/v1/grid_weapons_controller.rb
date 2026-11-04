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
      include IdResolvable
      include CollectionSourceConcern
      include PartyAuthorizationConcern
      include SubstituteGridPreloading
      include PartyFullLoading
      include GridItemActions

      grid_item GridWeapon, blueprint: GridWeaponBlueprint, view: :full,
                            positions: [-1, *0..11], party_param_keys: %i[weapon resolve]

      before_action :find_grid_item, only: GridItemActions::ROW_ACTIONS + %i[duplicate]
      before_action :find_party, only: GridItemActions::EDIT_ACTIONS + %i[resolve duplicate]
      before_action :find_incoming_weapon, only: %i[create resolve]
      before_action :authorize_party_edit!, only: GridItemActions::EDIT_ACTIONS + %i[resolve duplicate]

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

        # Validate collection source constraint before proceeding
        if weapon_params[:collection_weapon_id].present?
          collection_item = CollectionWeapon.find_by(id: weapon_params[:collection_weapon_id])
          return unless validate_collection_source!(@party, collection_item)
        end

        position = weapon_params[:position]
        collection_weapon_id = weapon_params[:collection_weapon_id]
        grid_weapon = GridWeapon.new(
          weapon_params.merge(
            party_id: @party.id,
            weapon_id: @incoming_weapon.id,
            uncap_level: collection_weapon_id.present? ? @incoming_weapon.max_uncap_level : @incoming_weapon.default_uncap_level(position),
            transcendence_step: @incoming_weapon.max_transcendence_step
          )
        )

        if grid_weapon.valid?
          save_weapon(grid_weapon)
        elsif grid_weapon.errors[:series].include?('must not conflict with existing weapons')
          handle_conflict(grid_weapon)
        else
          render_validation_error_response(grid_weapon)
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
        if weapon_params[:collection_weapon_id].present?
          collection_item = CollectionWeapon.find_by(id: weapon_params[:collection_weapon_id])
          return unless validate_collection_source!(@party, collection_item)
        end

        normalize_ax_fields!

        ActiveRecord::Base.transaction do
          @grid_item.assign_with_skill_level(weapon_params.except(:bullets).merge(seal_state_params(:weapon)))
          raise ActiveRecord::Rollback unless @grid_item.save

          update_bullet_loadout!(@grid_item, params[:weapon][:bullets]) if params.dig(:weapon, :bullets).present?
          apply_notes_sync!(weapon_params)
        end

        if @grid_item.errors.empty?
          @grid_item.reload
          render json: GridWeaponBlueprint.render(@grid_item, view: :full, root: :grid_weapon), status: :ok
        else
          render_validation_error_response(@grid_item)
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
        incoming = find_by_any_id(Weapon, resolve_params[:incoming])
        render_not_found_response('weapon') and return unless incoming

        # Every conflicting id must be a grid weapon in the target party.
        conflicting_ids = Array(resolve_params[:conflicting]).compact_blank.map(&:to_s).uniq
        conflicting_weapons = GridWeapon.where(id: conflicting_ids, party_id: @party.id).to_a
        render_not_found_response('grid_weapon') and return if conflicting_ids.empty? || conflicting_weapons.size != conflicting_ids.size

        # Destroy each conflicting weapon
        conflicting_weapons.each(&:destroy)

        # Destroy the weapon at the desired position if it exists
        if (existing_weapon = GridWeapon.find_by(party_id: @party.id, position: resolve_params[:position]))
          existing_weapon.destroy
        end

        position = resolve_params[:position]
        grid_weapon = GridWeapon.create!(
          party_id: @party.id,
          weapon_id: incoming.id,
          position: position,
          uncap_level: incoming.default_uncap_level(position),
          transcendence_step: incoming.max_transcendence_step
        )

        if grid_weapon.persisted?
          @party.mark_updated!
          render json: render_replaced_view(grid_weapon, resolve_params[:position]), status: :created
        else
          render_validation_error_response(grid_weapon)
        end
      end

      ##
      # Duplicates a GridWeapon to a new position.
      #
      # Creates a copy of the grid weapon at the specified target position using amoeba_dup.
      # AX skills and befoulment are nullified per the amoeba configuration.
      # Limited weapons (Opus, Draconic, etc.) cannot be duplicated.
      # Collection links are not carried over to the duplicate.
      #
      # @return [void]
      def duplicate
        # Block limited weapons
        if @grid_item.weapon.limit
          return render_unprocessable_entity_response(
            Api::V1::GranblueError.new('Limited weapons cannot be duplicated')
          )
        end

        position = duplicate_params[:position].to_i

        # Validate target position is a sub-weapon slot (0-8)
        unless (0..8).cover?(position)
          return render_unprocessable_entity_response(
            Api::V1::InvalidPositionError.new("Invalid duplicate target position #{position}")
          )
        end

        # Check target position is empty
        if GridWeapon.exists?(party_id: @party.id, position: position)
          return render_unprocessable_entity_response(
            Api::V1::PositionOccupiedError.new("Position #{position} is already occupied")
          )
        end

        new_weapon = @grid_item.amoeba_dup
        new_weapon.position = position
        new_weapon.collection_weapon_id = nil
        new_weapon.orphaned = false

        if new_weapon.save
          @party.mark_updated!
          render json: GridWeaponBlueprint.render(new_weapon, view: :full, root: :grid_weapon), status: :created
        else
          render_validation_error_response(new_weapon)
        end
      end

      private

      ##
      # Normalizes the AX modifier fields for the weapon parameters.
      #
      # Clears the AX and befoulment modifiers the client sent as -1 (none).
      #
      # @return [void]
      def normalize_ax_fields!
        raw = params.require(:weapon)
        %i[ax_modifier1_id ax_modifier2_id befoulment_modifier_id].each do |key|
          raw[key] = nil if weapon_params[key].to_i == -1
        end
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

        update_party_attributes_for_position(weapon, weapon.position.to_i)

        if weapon.save
          @party.mark_updated!
          weapon.sync_from_collection! if weapon.collection_weapon_id.present?
          # If another copy of this weapon in the party already runs a notes
          # sync group, the new slot auto-joins so the user doesn't have to
          # re-toggle the switch on it.
          NotesSync.adopt_for_new_item!(weapon)
          weapon.reload
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
        conflict_weapons = weapon.conflicts(@party)
        # Find if one of the conflicting grid weapons is associated with the incoming weapon.
        conflict_weapon = conflict_weapons.find { |gw| gw.weapon.id == @incoming_weapon.id }

        if conflict_weapon.nil?
          output = render_conflict_view(conflict_weapons, @incoming_weapon, weapon_params[:position])
          render json: output
        else
          old_position = conflict_weapon.position
          conflict_weapon.position = weapon_params[:position]
          if conflict_weapon.save
            output = render_replaced_view(conflict_weapon, old_position)
            render json: output
          else
            render_validation_error_response(conflict_weapon)
          end
        end
      end

      ##
      # Finds and sets the incoming weapon.
      #
      # @return [void]
      def find_incoming_weapon
        if params.dig(:weapon, :weapon_id).present?
          @incoming_weapon = find_by_any_id(Weapon, params.dig(:weapon, :weapon_id))
          render_not_found_response('weapon') unless @incoming_weapon
        else
          @incoming_weapon = nil
        end
      end

      def before_position_save(new_position)
        update_party_attributes_for_position(@grid_item, new_position)
      end

      # The moved weapon as loaded, so its substitutes keep their owned flags.
      def moved_grid_item_json
        GridWeaponBlueprint.render_as_hash(@grid_item, view: :full)
      end

      ##
      # Sets the party's element when a weapon takes the mainhand, and marks
      # the party as using extra slots when one takes an extra slot.
      #
      # @param grid_weapon [GridWeapon] the grid weapon placed.
      # @param new_position [Integer] the slot it takes.
      # @return [void]
      def update_party_attributes_for_position(grid_weapon, new_position)
        if new_position == -1
          @party.element = grid_weapon.weapon.element
          @party.save!
        elsif GridWeapon::EXTRA_POSITIONS.include?(new_position)
          @party.extra = true
          @party.save!
        end
      end

      ##
      # Replaces the weapon's bullets, rolling back on an invalid one.
      #
      # @return [void]
      def update_bullet_loadout!(grid_weapon, bullets_params)
        grid_weapon.grid_weapon_bullets.destroy_all

        bullets_params.each do |bullet_entry|
          gwb = grid_weapon.grid_weapon_bullets.build(
            bullet_id: bullet_entry[:bullet_id],
            position: bullet_entry[:position]
          )
          unless gwb.valid?
            gwb.errors.each { |error| grid_weapon.errors.add(:bullets, error.full_message) }
            raise ActiveRecord::Rollback
          end
          gwb.save!
        end
      end

      ##
      # Specifies and permits the allowed weapon parameters.
      #
      # @return [ActionController::Parameters] the permitted parameters.
      def weapon_params
        grid_item_params(
          :id, :weapon_id, :collection_weapon_id,
          :position, :mainhand, :uncap_level, :transcendence_step, :element,
          :weapon_key1_id, :weapon_key2_id, :weapon_key3_id,
          :ax_modifier1_id, :ax_modifier2_id, :ax_strength1, :ax_strength2,
          :befoulment_modifier_id, :befoulment_strength, :befoulment_permeation, :exorcism_level, :skill_level,
          :awakening_id, :awakening_level,
          :notes_synced,
          bullets: %i[position bullet_id]
        )
      end

      ##
      # Specifies and permits the resolve parameters.
      #
      # @return [ActionController::Parameters] the permitted parameters.
      def resolve_params
        params.expect(resolve: [:position, :incoming, { conflicting: [] }])
      end

      ##
      # Specifies and permits the duplicate parameters.
      #
      # @return [ActionController::Parameters] the permitted parameters.
      def duplicate_params
        params.permit(:position)
      end
    end
  end
end
