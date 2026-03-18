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
                         .includes(:playlist_parties, :user)
                         .visible_to(current_user, owner)
                         .order(updated_at: :desc)
                         .paginate(page: params[:page], per_page: page_size)

        raid_slugs_map = precompute_raid_slugs(playlists)

        render json: PlaylistBlueprint.render(
          playlists,
          root: :results,
          meta: pagination_meta(playlists),
          raid_slugs_map: raid_slugs_map
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

      def precompute_raid_slugs(playlists)
        all_party_ids = playlists.flat_map { |pl| pl.playlist_parties.map(&:party_id) }
        return {} if all_party_ids.empty?

        # Build a map of party_id => raid_id
        party_raid_pairs = Party.where(id: all_party_ids)
                                .where.not(raid_id: nil)
                                .pluck(:id, :raid_id, :updated_at)

        # Build raid slug lookup
        all_raid_ids = party_raid_pairs.map { |_, rid, _| rid }.uniq
        raid_slug_map = Raid.where(id: all_raid_ids).pluck(:id, :slug).to_h

        # Build per-playlist raid slugs
        playlists.each_with_object({}) do |pl, result|
          pl_party_ids = pl.playlist_parties.map(&:party_id).to_set
          relevant = party_raid_pairs.select { |pid, _, _| pl_party_ids.include?(pid) }

          # Group by raid_id, pick most recent updated_at per raid, sort desc, limit 4
          by_raid = relevant.group_by { |_, rid, _| rid }
          sorted = by_raid.map { |rid, entries| [rid, entries.map { |_, _, ts| ts }.max] }
                          .sort_by { |_, ts| -ts.to_i }
                          .first(4)

          result[pl.id] = sorted.filter_map { |rid, _| raid_slug_map[rid] }
        end
      end
    end
  end
end
