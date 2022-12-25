# frozen_string_literal: true

module Api
  module V1
    class GridWeaponsController < Api::V1::ApiController
      before_action :set, except: %w[create update_uncap_level destroy]

      def create
        # BUG: I can create grid weapons even when I'm not logged in on an authenticated party
        party = Party.find(weapon_params[:party_id])
        render_unauthorized_response if current_user && (party.user != current_user)

        incoming_weapon = Weapon.find(weapon_params[:weapon_id])
        incoming_weapon.limit

        # Set up conflict_position in case it is used
        conflict_position = nil

        # 1. If the weapon has a limit
        # 2. If the weapon does not match a weapon already in grid
        # 3. If the incoming weapon has a limit and other weapons of the same series are in grid
        if incoming_weapon.limit && incoming_weapon.limit.positive?
          conflict_weapon = party.weapons.find do |weapon|
            weapon if incoming_weapon.series == weapon.weapon.series ||
                      ([2, 3].include?(incoming_weapon.series) && [2, 3].include?(weapon.weapon.series))
          end

          if conflict_weapon
            if conflict_weapon.weapon.id != incoming_weapon.id
              return render json: ConflictBlueprint.render(nil, view: :weapons,
                                                                conflict_weapons: [conflict_weapon],
                                                                incoming_weapon: incoming_weapon,
                                                                incoming_position: weapon_params[:position])
            else
              # Destroy the original grid weapon
              # TODO: Use conflict_position to alert the client that that position has changed
              conflict_position = conflict_weapon.position
              GridWeapon.destroy(conflict_weapon.id)
            end
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

        # Render the new weapon and any weapons changed
        return unless weapon.save!

        render json: GridWeaponBlueprint.render(weapon, view: :full,
                                                        root: :grid_weapon,
                                                        meta: {
                                                          replaced: conflict_position
                                                        }),
               status: :created
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
