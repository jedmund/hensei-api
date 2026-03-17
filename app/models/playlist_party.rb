# frozen_string_literal: true

class PlaylistParty < ApplicationRecord
  belongs_to :playlist
  belongs_to :party

  validates :party_id, uniqueness: { scope: :playlist_id }
end
