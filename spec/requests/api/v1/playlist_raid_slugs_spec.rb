# frozen_string_literal: true

require 'rails_helper'

# GET /users/:user_id/playlists: each playlist's raid_slugs are its raids,
# one per raid, most recently updated team first, at most four.
RSpec.describe 'Playlist raid slugs', type: :request do
  let(:owner) { create(:user) }
  let(:playlist) { create(:playlist, user: owner, visibility: 1) }
  let(:empty_playlist) { create(:playlist, user: owner, visibility: 1) }
  let(:raids) { create_list(:raid, 5) }

  def add(raid, updated_at, visibility: 1)
    party = create(:party, user: owner, visibility: visibility, raid: raid)
    party.update_column(:updated_at, updated_at)
    create(:playlist_party, playlist: playlist, party: party)
    party
  end

  def slugs_for(target)
    get "/api/v1/users/#{owner.username}/playlists"
    response.parsed_body['results'].find { |p| p['id'] == target.id }['raid_slugs']
  end

  it 'lists at most four raids, newest team first, once each' do
    add(raids[0], 5.days.ago)
    add(raids[1], 4.days.ago)
    add(raids[2], 3.days.ago)
    add(raids[3], 2.days.ago)
    add(raids[4], 1.day.ago)
    add(raids[0], 1.hour.ago)

    expect(slugs_for(playlist)).to eq([raids[0], raids[4], raids[3], raids[2]].map(&:slug))
  end

  it 'skips teams without a raid and returns none for an empty playlist' do
    add(nil, 1.hour.ago)
    add(raids[1], 1.day.ago)
    empty_playlist

    expect(slugs_for(playlist)).to eq([raids[1].slug])
    expect(slugs_for(empty_playlist)).to eq([])
  end

  it "leaves out raids only another user's private teams use" do
    add(raids[2], 1.day.ago)
    hidden = create(:party, user: create(:user), visibility: 3, raid: raids[3])
    create(:playlist_party, playlist: playlist, party: hidden)

    expect(slugs_for(playlist)).to eq([raids[2].slug])
  end
end
