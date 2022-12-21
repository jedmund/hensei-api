# frozen_string_literal: true

module Api
  module V1
    class FavoritesController < Api::V1::ApiController
      before_action :set_party, only: ['create']

      def create
        party_id = favorite_params[:party_id]
        party = Party.find(party_id)

        raise Api::V1::UnauthorizedError unless current_user
        raise Api::V1::SameFavoriteUserError if party.user && current_user.id == party.user.id
        raise Api::V1::FavoriteAlreadyExistsError if Favorite.where(user_id: current_user.id,
                                                                    party_id: party_id).length.positive?

        @favorite = Favorite.new({
                                   user_id: current_user.id,
                                   party_id: party_id
                                 })
        render :show, status: :created if @favorite.save!
      end

      def destroy
        raise Api::V1::UnauthorizedError unless current_user

        @favorite = Favorite.where(user_id: current_user.id, party_id: favorite_params[:party_id]).first
        render :destroyed, status: :ok if @favorite && Favorite.destroy(@favorite.id)
      end

      private

      def set_party
        @party = Party.where('id = ?', params[:party_id]).first
      end

      def favorite_params
        params.require(:favorite).permit(:party_id)
      end
    end
  end
end
