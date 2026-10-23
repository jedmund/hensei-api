# frozen_string_literal: true

##
# Viewer options for rendering playlists with PlaylistBlueprint, which only
# lists the parties the viewer may see.
module PlaylistRendering
  extend ActiveSupport::Concern

  private

  # @param playlists [Enumerable<Playlist>] with playlist_parties loaded
  # @return [Hash] options to pass to PlaylistBlueprint.render
  def playlist_render_options(playlists)
    {
      current_user: current_user,
      admin_mode: admin_mode,
      visible_party_ids: Api::V1::PlaylistBlueprint.visible_party_ids_for(playlists, current_user,
                                                                          admin_mode: admin_mode)
    }
  end
end
