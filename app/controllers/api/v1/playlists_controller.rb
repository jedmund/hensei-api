# frozen_string_literal: true

module Api
  module V1
    class PlaylistsController < Api::V1::ApiController
      before_action :set_playlist, only: %i[update destroy]
      before_action :authorize_owner!, only: %i[update destroy]

      # GET /users/:user_id/playlists
      def index
        owner = User.find_by!(username: params[:user_id])
        playlists = owner.playlists
                         .includes(:playlist_parties)
                         .visible_to(current_user, owner)
                         .order(updated_at: :desc)
                         .paginate(page: params[:page], per_page: page_size)

        render json: PlaylistBlueprint.render(
          playlists,
          root: :results,
          meta: pagination_meta(playlists)
        )
      end

      # GET /users/:user_id/playlists/:id
      def show
        owner = User.find_by!(username: params[:user_id])
        playlist = owner.playlists.find_by!(slug: params[:id])

        unless playlist.viewable_by?(current_user)
          return render_not_found_response('playlist')
        end

        favorite_party_ids = current_user ? current_user.favorites.pluck(:party_id).to_set : Set.new

        render json: PlaylistBlueprint.render(
          playlist,
          view: :with_parties,
          root: :playlist,
          current_user: current_user,
          favorite_party_ids: favorite_party_ids
        )
      end

      # POST /playlists
      def create
        raise Api::V1::UnauthorizedError unless current_user

        playlist = current_user.playlists.build(playlist_params)

        if playlist.save
          render json: PlaylistBlueprint.render(playlist, root: :playlist), status: :created
        else
          render_validation_error_response(playlist)
        end
      end

      # PATCH /playlists/:id
      def update
        if @playlist.update(playlist_params)
          render json: PlaylistBlueprint.render(@playlist, root: :playlist)
        else
          render_validation_error_response(@playlist)
        end
      end

      # DELETE /playlists/:id
      def destroy
        @playlist.destroy!
        head :no_content
      end

      private

      def set_playlist
        @playlist = Playlist.find(params[:id])
      end

      def authorize_owner!
        render_unauthorized_response unless @playlist.owned_by?(current_user)
      end

      def playlist_params
        params.require(:playlist).permit(:title, :description, :video_url, :visibility)
      end
    end
  end
end
