# frozen_string_literal: true

require 'rails_helper'

# GET /crew/gw_participations/by_event/:event_id: who is listed for a past
# event, and which of them were in the crew while it ran.
RSpec.describe 'Crew GW participation by event', type: :request do
  let(:user) { create(:user) }
  let(:headers) do
    token = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}" }
  end
  let(:crew) { create(:crew) }
  let(:event) { create(:gw_event, :finished) }
  let!(:captain) { create(:crew_membership, crew: crew, user: user, role: :captain, joined_at: 2.months.ago) }
  let!(:late_joiner) { create(:crew_membership, crew: crew, user: create(:user), role: :member, joined_at: 1.day.ago) }
  let!(:retired_after) do
    create(:crew_membership, crew: crew, user: create(:user), role: :member, joined_at: 2.months.ago,
                             retired: true, retired_at: 1.week.ago)
  end
  let!(:phantom) { create(:phantom_player, crew: crew, joined_at: 2.months.ago) }
  let!(:new_phantom) { create(:phantom_player, crew: crew, joined_at: 1.day.ago) }

  before do
    # Left out: retired before the event, and deleted
    create(:crew_membership, crew: crew, user: create(:user), role: :member, joined_at: 2.months.ago,
                             retired: true, retired_at: 1.month.ago)
    create(:phantom_player, crew: crew, joined_at: 2.months.ago, deleted_at: 1.day.ago)
  end

  def flags(list)
    list.to_h { |entry| [entry['id'], entry['active_during_event']] }
  end

  it 'lists members and phantoms active then or now, flagging who was active then' do
    get "/api/v1/crew/gw_participations/by_event/#{event.id}", headers: headers

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body.keys).to eq(%w[gw_event crew_gw_participation members_during_event phantom_players])
    expect(body['crew_gw_participation']).to be_nil
    expect(flags(body['members_during_event'])).to eq(captain.id => true, late_joiner.id => false,
                                                      retired_after.id => true)
    expect(flags(body['phantom_players'])).to eq(phantom.id => true, new_phantom.id => false)
    expect(body['members_during_event'].first['user']).to be_present
  end

  it "returns the crew's participation with its scores, never another crew's" do
    participation = create(:crew_gw_participation, crew: crew, event: event)
    create(:crew_gw_participation, crew: create(:crew), event: event)

    get "/api/v1/crew/gw_participations/by_event/#{event.event_number}", headers: headers

    expect(response.parsed_body['crew_gw_participation']['id']).to eq(participation.id)
  end

  it 'returns empty lists and no phantoms key for an unknown event' do
    get "/api/v1/crew/gw_participations/by_event/#{SecureRandom.uuid}", headers: headers

    expect(response.parsed_body).to eq('gw_event' => nil, 'crew_gw_participation' => nil, 'members_during_event' => [])
  end

  it 'requires authentication' do
    get "/api/v1/crew/gw_participations/by_event/#{event.id}"

    expect(response).to have_http_status(:unauthorized)
  end
end
