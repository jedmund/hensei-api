# frozen_string_literal: true

module Api
  module V1
    class GridWeaponsController < Api::V1::ApiController
      attr_reader :party, :incoming_weapon

      before_action :find_party, only: :create
      before_action :find_incoming_weapon, only: :create
      before_action :check_weapon_compatibility, only: :create
      before_action :set, except: %w[create update_uncap_level destroy]

      def create
        if conflict_weapon
          if conflict_weapon.weapon.id != incoming_weapon.id
            # Render the conflict view as a string and assign it to a variable
            conflict_view = render_conflict_view(conflict_weapon, incoming_weapon, weapon_params[:position])
            return render json: conflict_view
          else
            # Destroy the original grid weapon
            # TODO: Use conflict_position to alert the client that that position has changed
            conflict_position = conflict_weapon.position
            GridWeapon.destroy(conflict_weapon.id)
          end
        end

        # Destroy the existing item before adding a new one
        if (grid_weapon = GridWeapon.where(
          party_id: party.id,
          position: weapon_params[:position]
        ).first)
          GridWeapon.destroy(grid_weapon.id)
        end

        weapon = GridWeapon.new
        weapon.attributes = weapon_params.merge(party_id: party.id, weapon_id: incoming_weapon.id)

        if weapon.position == -1
          party.element = weapon.weapon.element
          party.save!
        end

        # Render the grid weapon view as a string and assign it to a variable
        return unless weapon.save!

        grid_weapon_view = render_grid_weapon_view(weapon, conflict_position)
        render json: grid_weapon_view, status: :created
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
        render json: GridWeaponBlueprint.render(weapon, view: :nested), status: :created if weapon.save!
      end

      def update
        render_unauthorized_response if current_user && (@weapon.party.user != current_user)

        # TODO: Server-side validation of weapon mods
        # We don't want someone modifying the JSON and adding
        # keys to weapons that cannot have them

        # Maybe we make methods on the model to validate for us somehow

        render json: GridWeaponBlueprint.render(@weapon, view: :nested) if @weapon.update(weapon_params)
      end

      # TODO: Implement removing characters
      def destroy; end

      def update_uncap_level
        weapon = GridWeapon.find(weapon_params[:id])

        render_unauthorized_response if current_user && (weapon.party.user != current_user)

        weapon.uncap_level = weapon_params[:uncap_level]
        return unless weapon.save!

        render json: GridWeaponBlueprint.render(weapon, view: :nested, root: :grid_weapon),
               status: :created
      end

      private

      def check_weapon_compatibility
        return if compatible_with_position?(incoming_weapon, weapon_params[:position])

        raise Api::V1::IncompatibleWeaponForPositionError.new(weapon: incoming_weapon)
      end

      # Check if the incoming weapon is compatible with the specified position
      def compatible_with_position?(incoming_weapon, position)
        false if [9, 10, 11].include?(position.to_i) && ![11, 16, 17, 28, 29].include?(incoming_weapon.series)
        true
      end

      def conflict_weapon
        @conflict_weapon ||= find_conflict_weapon(party, incoming_weapon)
      end

      # Find a conflict weapon if one exists
      def find_conflict_weapon(party, incoming_weapon)
        return unless incoming_weapon.limit

        party.weapons.find do |weapon|
          weapon if incoming_weapon.series == weapon.weapon.series || [2, 3].include?(weapon.weapon.series)
        end
      end

      def find_incoming_weapon
        @incoming_weapon = Weapon.find(weapon_params[:weapon_id])
        @incoming_weapon.limit
      end

      def find_party
        # BUG: I can create grid weapons even when I'm not logged in on an authenticated party
        @party = Party.find(weapon_params[:party_id])
        render_unauthorized_response if current_user && (party.user != current_user)
      end

      # Render the conflict view as a string
      def render_conflict_view(conflict_weapon, incoming_weapon, incoming_position)
        ConflictBlueprint.render(nil, view: :weapons,
                                      conflict_weapons: [conflict_weapon],
                                      incoming_weapon: incoming_weapon,
                                      incoming_position: incoming_position)
      end

      def render_grid_weapon_view(grid_weapon, conflict_position)
        GridWeaponBlueprint.render(grid_weapon, view: :full,
                                                root: :grid_weapon,
                                                meta: { replaced: conflict_position })
      end

      def set
        @weapon = GridWeapon.where('id = ?', params[:id]).first
      end

      # Specify whitelisted properties that can be modified.
      def weapon_params
        params.require(:weapon).permit(
          :id, :party_id, :weapon_id,
          :position, :mainhand, :uncap_level, :element,
          :weapon_key1_id, :weapon_key2_id, :weapon_key3_id,
          :ax_modifier1, :ax_modifier2, :ax_strength1, :ax_strength2,
          :awakening_type, :awakening_level
        )
      end

      def resolve_params
        params.require(:resolve).permit(:position, :incoming, conflicting: [])
      end
    end
  end
end
