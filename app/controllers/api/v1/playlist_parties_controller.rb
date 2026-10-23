# frozen_string_literal: true

module Api
  module V1
    class PlaylistPartiesController < Api::V1::ApiController
      include PlaylistRendering

      before_action :set_playlist
      before_action :authorize_owner!

      # POST /playlists/:playlist_id/parties
      def create
        # Unknown and hidden parties get the same response.
        party = Party.find_by(id: params[:party_id])
        return render_not_found_response('party') unless party&.viewable_by?(current_user)

        playlist_party = @playlist.playlist_parties.build(party: party)

        if playlist_party.save
          @playlist.reload
          render json: PlaylistBlueprint.render(@playlist, root: :playlist, **playlist_render_options([@playlist])),
                 status: :created
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
