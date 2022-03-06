class Api::V1::GridWeaponsController < Api::V1::ApiController
    before_action :set, except: ['create', 'update_uncap_level', 'destroy']

    def create
        party = Party.find(weapon_params[:party_id])
        canonical_weapon = Weapon.find(weapon_params[:weapon_id])

        if current_user
            if party.user != current_user
                render_unauthorized_response
            end
        end

        if grid_weapon = GridWeapon.where(
            party_id: party.id, 
            position: weapon_params[:position]
        ).first
            GridWeapon.destroy(grid_weapon.id)
        end

        @weapon = GridWeapon.create!(weapon_params.merge(party_id: party.id, weapon_id: canonical_weapon.id))

        if (@weapon.position == -1)
            party.element = @weapon.weapon.element
            party.save!
        end

        render :show, status: :created if @weapon.save!
    end

    def update
        if current_user
            if @weapon.party.user != current_user
                render_unauthorized_response
            end
        end

        # TODO: Server-side validation of weapon mods
        # We don't want someone modifying the JSON and adding
        # keys to weapons that cannot have them

        # Maybe we make methods on the model to validate for us somehow

        render :update, status: :ok if @weapon.update(weapon_params)
    end

    def update_uncap_level
        @weapon = GridWeapon.find(weapon_params[:id])

        if current_user
            if party.user != current_user
                render_unauthorized_response
            end
        end

        @weapon.uncap_level = weapon_params[:uncap_level]
        render :show, status: :ok if @weapon.save!
    end

    private

    def set
        @weapon = GridWeapon.where("id = ?", params[:id]).first
    end

    # Specify whitelisted properties that can be modified.
    def weapon_params
        params.require(:weapon).permit(
            :id, :party_id, :weapon_id, 
            :position, :mainhand, :uncap_level, :element, 
            :weapon_key1_id, :weapon_key2_id, :weapon_key3_id,
            :ax_modifier1, :ax_modifier2, :ax_strength1, :ax_strength2
        )
    end
end