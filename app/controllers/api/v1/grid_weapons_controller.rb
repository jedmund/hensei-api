class Api::V1::GridWeaponsController < Api::V1::ApiController
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
        render :show, status: :created if @weapon.save!
    end

    def destroy
    end

    private

    # Specify whitelisted properties that can be modified.
    def weapon_params
        params.require(:weapon).permit(:party_id, :weapon_id, :position, :mainhand)
    end
end