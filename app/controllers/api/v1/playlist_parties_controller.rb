# frozen_string_literal: true

module Api
  module V1
    class PlaylistPartiesController < Api::V1::ApiController
      before_action :set_playlist
      before_action :authorize_owner!

      # POST /playlists/:playlist_id/parties
      def create
        playlist_party = @playlist.playlist_parties.build(party_id: params[:party_id])

        if playlist_party.save
          render json: PlaylistBlueprint.render(@playlist.reload, root: :playlist), status: :created
        else
          render_validation_error_response(playlist_party)
        end
      end

      # DELETE /playlists/:playlist_id/parties/:id
      def destroy
        playlist_party = @playlist.playlist_parties.find_by!(party_id: params[:id])
        playlist_party.destroy!
        head :no_content
      end

      private

      def set_playlist
        @playlist = Playlist.find(params[:playlist_id])
      end

      def authorize_owner!
        raise Api::V1::UnauthorizedError unless current_user
        render_unauthorized_response unless @playlist.owned_by?(current_user)
      end
    end
  end
end
