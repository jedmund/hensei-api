# frozen_string_literal: true

module Api
  module V1
    class GridWeaponsController < Api::V1::ApiController
      before_action :set, except: %w[create update_uncap_level destroy]

      def create
        party = Party.find(weapon_params[:party_id])
        canonical_weapon = Weapon.find(weapon_params[:weapon_id])

        render_unauthorized_response if current_user && (party.user != current_user)

        if (grid_weapon = GridWeapon.where(
          party_id: party.id,
          position: weapon_params[:position]
        ).first)
          GridWeapon.destroy(grid_weapon.id)
        end

        weapon = GridWeapon.create!(weapon_params.merge(party_id: party.id, weapon_id: canonical_weapon.id))

        if weapon.position == -1
          party.element = weapon.weapon.element
          party.save!
        end

        render json: GridWeaponBlueprint.render(weapon, view: :full), status: :created if weapon.save!
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
    end
  end
end
