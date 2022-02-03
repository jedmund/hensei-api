class Api::V1::GridCharactersController < Api::V1::ApiController
    def create
        party = Party.find(character_params[:party_id])
        canonical_character = Character.find(character_params[:character_id])
 
        if current_user
            if party.user != current_user
                render_unauthorized_response
            end
        end

        if grid_character = GridCharacter.where(
            party_id: party.id, 
            position: character_params[:position]
        ).first
            GridCharacter.destroy(grid_character.id)
        end

        @character = GridCharacter.create!(character_params.merge(party_id: party.id, character_id: canonical_character.id))
        render :show, status: :created if @character.save!
    end

    def update_uncap_level
        @character = GridCharacter.find(character_params[:id])

        if current_user
            if @character.party.user != current_user
                render_unauthorized_response
            end
        end

        @character.uncap_level = character_params[:uncap_level]
        render :show, status: :ok if @character.save!
    end

    def destroy
    end

    private

    # Specify whitelisted properties that can be modified.
    def character_params
        params.require(:character).permit(:id, :party_id, :character_id, :position, :uncap_level)
    end
end