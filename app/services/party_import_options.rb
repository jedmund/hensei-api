# frozen_string_literal: true

##
# The party options a POST /import body carries, for game decks and Evoking
# Solomonis imports alike: visibility, name and the playlists to add the
# party to.
class PartyImportOptions
  VISIBILITIES = [1, 2, 3].freeze

  # @param user [User] the importing user
  # @param body [Hash] the parsed request body
  def initialize(user, body)
    @user = user
    @body = body
  end

  # The requested visibility, else the user's default for imports.
  def visibility
    requested_visibility || @user.default_import_visibility
  end

  # The body's visibility (1, 2 or 3, as a number or digit string), or nil
  # when it's missing or anything else.
  def requested_visibility
    value = @body['visibility']
    value = value.to_i if value.is_a?(String) && value.match?(/\A\d\z/)
    value if VISIBILITIES.include?(value)
  end

  # Adds the party to the playlists named in playlist_ids that the user owns;
  # other ids are ignored.
  def assign_playlists(party)
    return if @body['playlist_ids'].blank?

    Array(@body['playlist_ids']).each do |playlist_id|
      playlist = @user.playlists.find_by(id: playlist_id)
      next unless playlist

      PlaylistParty.find_or_create_by!(playlist: playlist, party: party)
    end
  end
end
