# frozen_string_literal: true

module Api
  module V1
    class GridWeaponsController < Api::V1::ApiController
      attr_reader :party, :incoming_weapon

      before_action :set, except: %w[create update_uncap_level]
      before_action :find_party, only: :create
      before_action :find_incoming_weapon, only: :create
      before_action :authorize, only: %i[create update destroy]

      def create
        # Create the GridWeapon with the desired parameters
        weapon = GridWeapon.new
        weapon.attributes = weapon_params.merge(party_id: party.id, weapon_id: incoming_weapon.id)

        if weapon.validate
          save_weapon(weapon)
        else
          handle_conflict(weapon)
        end
      end

      def resolve
        incoming = Weapon.find(resolve_params[:incoming])
        conflicting = resolve_params[:conflicting].map { |id| GridWeapon.find(id) }
        party = conflicting.first.party

        # Destroy each conflicting weapon
        conflicting.each { |weapon| GridWeapon.destroy(weapon.id) }

        # Destroy the weapon at the desired position if it exists
        existing_weapon = GridWeapon.where(party: party.id, position: resolve_params[:position]).first
        GridWeapon.destroy(existing_weapon.id) if existing_weapon

        uncap_level = 3
        uncap_level = 4 if incoming.flb
        uncap_level = 5 if incoming.ulb

        weapon = GridWeapon.create!(party_id: party.id, weapon_id: incoming.id,
                                    position: resolve_params[:position], uncap_level: uncap_level)

        return unless weapon.save

        view = render_grid_weapon_view(weapon, resolve_params[:position])
        render json: view, status: :created
      end

      def update
        render_unauthorized_response if current_user && (@weapon.party.user != current_user)

        # TODO: Server-side validation of weapon mods
        # We don't want someone modifying the JSON and adding
        # keys to weapons that cannot have them

        # Maybe we make methods on the model to validate for us somehow

        @weapon.assign_attributes(weapon_params)

        @weapon.ax_modifier1 = nil if weapon_params[:ax_modifier1] == -1
        @weapon.ax_modifier2 = nil if weapon_params[:ax_modifier2] == -1
        @weapon.ax_strength1 = nil if weapon_params[:ax_strength1]&.zero?
        @weapon.ax_strength2 = nil if weapon_params[:ax_strength2]&.zero?

        render json: GridWeaponBlueprint.render(@weapon, view: :nested) if @weapon.save
      end

      def destroy
        render_unauthorized_response if @weapon.party.user != current_user
        return render json: GridCharacterBlueprint.render(@weapon, view: :destroyed) if @weapon.destroy
      end

      def update_uncap_level
        weapon = GridWeapon.find(weapon_params[:id])
        object = weapon.weapon
        max_uncap_level = max_uncap_level(object)

        render_unauthorized_response if current_user && (weapon.party.user != current_user)

        greater_than_max_uncap = weapon_params[:uncap_level].to_i > max_uncap_level
        can_be_transcended = object.transcendence && weapon_params[:transcendence_step] && weapon_params[:transcendence_step]&.to_i&.positive?

        uncap_level = if greater_than_max_uncap || can_be_transcended
                        max_uncap_level
                      else
                        weapon_params[:uncap_level]
                      end

        transcendence_step = if object.transcendence && weapon_params[:transcendence_step]
                               weapon_params[:transcendence_step]
                             else
                               0
                             end

        weapon.update!(
          uncap_level: uncap_level,
          transcendence_step: transcendence_step
        )

        return unless weapon.persisted?

        render json: GridWeaponBlueprint.render(weapon, view: :nested, root: :grid_weapon)
      end

      private

      def max_uncap_level(weapon)
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

      def check_weapon_compatibility
        return if compatible_with_position?(incoming_weapon, weapon_params[:position])

        raise Api::V1::IncompatibleWeaponForPositionError.new(weapon: incoming_weapon)
      end

      # Check if the incoming weapon is compatible with the specified position
      def compatible_with_position?(incoming_weapon, position)
        false if [9, 10, 11].include?(position.to_i) && ![11, 16, 17, 28, 29, 34].include?(incoming_weapon.series)
        true
      end

      def conflict_weapon
        @conflict_weapon ||= find_conflict_weapon(party, incoming_weapon)
      end

      # Find a conflict weapon if one exists
      def find_conflict_weapon(party, incoming_weapon)
        return unless incoming_weapon.limit

        party.weapons.find do |weapon|
          series_match = incoming_weapon.series == weapon.weapon.series
          weapon if series_match || opus_or_draconic?(weapon.weapon) && opus_or_draconic?(incoming_weapon)
        end
      end

      def find_incoming_weapon
        @incoming_weapon = Weapon.find_by(id: weapon_params[:weapon_id])
      end

      def find_party
        # BUG: I can create grid weapons even when I'm not logged in on an authenticated party
        @party = Party.find(weapon_params[:party_id])
        render_unauthorized_response if current_user && (party.user != current_user)
      end

      def opus_or_draconic?(weapon)
        [2, 3].include?(weapon.series)
      end

      # Render the conflict view as a string
      def render_conflict_view(conflict_weapons, incoming_weapon, incoming_position)
        ConflictBlueprint.render(nil, view: :weapons,
                                      conflict_weapons: conflict_weapons,
                                      incoming_weapon: incoming_weapon,
                                      incoming_position: incoming_position)
      end

      def render_grid_weapon_view(grid_weapon, conflict_position)
        GridWeaponBlueprint.render(grid_weapon, view: :full,
                                                root: :grid_weapon,
                                                meta: { replaced: conflict_position })
      end

      def save_weapon(weapon)
        # Check weapon validation and delete existing grid weapon
        # if one already exists at position
        if (grid_weapon = GridWeapon.where(
          party_id: party.id,
          position: weapon_params[:position]
        ).first)
          GridWeapon.destroy(grid_weapon.id)
        end

        # Set the party's element if the grid weapon is being set as mainhand
        if weapon.position == -1
          party.element = weapon.weapon.element
          party.save!
        elsif [9, 10, 11].include?(weapon.position)
          party.extra = true
          party.save!
        end

        # Render the weapon if it can be saved
        return unless weapon.save

        output = GridWeaponBlueprint.render(weapon, view: :full, root: :grid_weapon)
        render json: output, status: :created
      end

      def handle_conflict(weapon)
        conflict_weapons = weapon.conflicts(party)

        # Map conflict weapon IDs into an array
        conflict_weapon_ids = conflict_weapons.map(&:id)
        if !conflict_weapon_ids.include?(incoming_weapon.id)
          # Render conflict view if the underlying canonical weapons
          # are not identical
          output = render_conflict_view(conflict_weapons, incoming_weapon, weapon_params[:position])
          render json: output
        else
          # Move the original grid weapon to the new position
          # to preserve keys and other modifications
          old_position = conflict_weapon.position
          conflict_weapon.position = weapon_params[:position]

          if conflict_weapon.save
            output = render_grid_weapon_view(conflict_weapon, old_position)
            render json: output
          end
        end
      end

      def set
        @weapon = GridWeapon.where('id = ?', params[:id]).first
      end

      def authorize
        # Create
        unauthorized_create = @party && (@party.user != current_user || @party.edit_key != edit_key)
        unauthorized_update = @weapon && @weapon.party && (@weapon.party.user != current_user || @weapon.party.edit_key != edit_key)

        render_unauthorized_response if unauthorized_create || unauthorized_update
      end

      # Specify whitelisted properties that can be modified.
      def weapon_params
        params.require(:weapon).permit(
          :id, :party_id, :weapon_id,
          :position, :mainhand, :uncap_level, :transcendence_step, :element,
          :weapon_key1_id, :weapon_key2_id, :weapon_key3_id,
          :ax_modifier1, :ax_modifier2, :ax_strength1, :ax_strength2,
          :awakening_id, :awakening_level
        )
      end

      def resolve_params
        params.require(:resolve).permit(:position, :incoming, conflicting: [])
      end
    end
  end
end
