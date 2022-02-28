class Api::V1::FavoritesController < Api::V1::ApiController
    before_action :set_party, only: ['create']

    def create
        party_id = favorite_params[:party_id]
        party = Party.find(party_id)

        if !current_user
            raise Api::V1::UnauthorizedError
        elsif party.user && current_user.id == party.user.id
            raise Api::V1::SameFavoriteUserError
        elsif Favorite.where(user_id: current_user.id, party_id: party_id).length > 0
            raise Api::V1::FavoriteAlreadyExistsError
        else
            ap "Create a new favorite"
            object = {
                user_id: current_user.id,
                party_id: favorite_params[:party_id]
            }

            @favorite = Favorite.new(object)
            render :show, status: :created if @favorite.save!
        end
    end

    def destroy
        raise Api::V1::UnauthorizedError unless current_user
        
        @favorite = Favorite.where(user_id: current_user.id, party_id: favorite_params[:party_id]).first
        render :destroyed, status: :ok if @favorite && Favorite.destroy(@favorite.id)
    end

    private

    def set_party
        @party = Party.where("id = ?", params[:party_id]).first
    end

    def favorite_params
        params.require(:favorite).permit(:id, :party_id)
    end
end