class Api::V1::GridSummonsController < Api::V1::ApiController
    def create
        party = Party.find(summon_params[:party_id])
        canonical_summon = Summon.find(summon_params[:summon_id])
 
        if current_user
            if party.user != current_user
                render_unauthorized_response
            end
        end

        if grid_summon = GridSummon.where(
            party_id: party.id, 
            position: summon_params[:position]
        ).first
            GridSummon.destroy(grid_summon.id)
        end

        @summon = GridSummon.create!(summon_params.merge(party_id: party.id, summon_id: canonical_summon.id))
        render :show, status: :created if @summon.save!
    end
    
    def update_uncap_level
        @summon = GridSummon.find@summon_params[:id])

        if current_user
            if @summon.party.user != current_user
                render_unauthorized_response
            end
        end

        @summon.uncap_level = summon_params[:uncap_level]
        render :show, status: :ok if @summon.save!
    end

    def destroy
    end

    private

    # Specify whitelisted properties that can be modified.
    def summon_params
        params.require(:summon).permit(:party_id, :summon_id, :position, :main, :friend, :uncap_level)
    end
end