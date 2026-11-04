# frozen_string_literal: true

require 'rails_helper'

# Pins the full GET /crew/crew_rosters/:id body: enriched items for every
# item type, in roster order, and each active member's copies.
RSpec.describe 'Crew roster ownership', type: :request do
  let(:user) { create(:user) }
  let(:headers) do
    token = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}" }
  end
  let(:crew) { create(:crew) }
  let(:character) { create(:character, element: 2, season: 1, flb: true, ulb: false, transcendence: false, special: false) }
  let(:weapon) { create(:weapon, element: 2, flb: true, ulb: false, transcendence: false) }
  let(:summon) { create(:summon, element: 2, flb: true, ulb: true, transcendence: false) }
  let(:roster) do
    create(:crew_roster, crew: crew, created_by: user, element: 2, name: 'Water',
                         items: [{ 'id' => summon.id, 'type' => 'Summon' },
                                 { 'id' => character.id, 'type' => 'Character' },
                                 { 'id' => weapon.id, 'type' => 'Weapon' }])
  end
  let(:member) { create(:user, collection_privacy: :everyone) }
  let(:hidden) { create(:user, collection_privacy: :private_collection) }

  before do
    create(:crew_membership, crew: crew, user: user, role: :member)
    create(:crew_membership, crew: crew, user: member, role: :member)
    create(:crew_membership, crew: crew, user: hidden, role: :member)
    [member, hidden].each do |owner|
      create(:collection_character, user: owner, character: character, uncap_level: 4, transcendence_step: 0)
      create(:collection_weapon, user: owner, weapon: weapon, uncap_level: 4, transcendence_step: 0)
      create(:collection_summon, user: owner, summon: summon, uncap_level: 5, transcendence_step: 0)
    end
  end

  it 'returns every item type in roster order with each member\'s copies' do
    get "/api/v1/crew/crew_rosters/#{roster.id}", headers: headers

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body['items']).to eq([
                                  { 'id' => summon.id, 'type' => 'Summon', 'granblue_id' => summon.granblue_id,
                                    'name' => summon.name_en, 'element' => 2,
                                    'uncap' => { 'flb' => true, 'ulb' => true, 'transcendence' => false } },
                                  { 'id' => character.id, 'type' => 'Character', 'granblue_id' => character.granblue_id,
                                    'name' => character.name_en, 'element' => 2, 'season' => 1,
                                    'uncap' => { 'flb' => true, 'ulb' => false, 'transcendence' => false },
                                    'special' => false },
                                  { 'id' => weapon.id, 'type' => 'Weapon', 'granblue_id' => weapon.granblue_id,
                                    'name' => weapon.name_en, 'element' => 2,
                                    'uncap' => { 'flb' => true, 'ulb' => false, 'transcendence' => false } }
                                ])

    shown = body['members'].find { |m| m['user_id'] == member.id }
    expect(shown).to eq(
      'user_id' => member.id, 'username' => member.username, 'role' => 'member',
      'characters' => [{ 'id' => character.id, 'uncap_level' => 4, 'transcendence_step' => 0, 'flb' => true,
                         'ulb' => false, 'transcendence' => false, 'special' => false }],
      'weapons' => [{ 'id' => weapon.id, 'uncap_level' => 4, 'transcendence_step' => 0, 'flb' => true,
                      'ulb' => false, 'transcendence' => false }],
      'summons' => [{ 'id' => summon.id, 'uncap_level' => 5, 'transcendence_step' => 0, 'flb' => true,
                      'ulb' => true, 'transcendence' => false }]
    )
  end

  it 'lists members with private collections but none of their copies' do
    get "/api/v1/crew/crew_rosters/#{roster.id}", headers: headers

    private_member = response.parsed_body['members'].find { |m| m['user_id'] == hidden.id }
    expect(private_member).to include('characters' => [], 'weapons' => [], 'summons' => [])
  end

  it 'skips item types the roster does not hold' do
    roster.update!(items: [{ 'id' => weapon.id, 'type' => 'Weapon' }])

    get "/api/v1/crew/crew_rosters/#{roster.id}", headers: headers

    body = response.parsed_body
    expect(body['items'].pluck('type')).to eq(['Weapon'])
    shown = body['members'].find { |m| m['user_id'] == member.id }
    expect(shown).to include('characters' => [], 'summons' => [])
    expect(shown['weapons'].size).to eq(1)
  end

  it "returns 404 for another crew's roster" do
    other = create(:crew_roster, crew: create(:crew), created_by: create(:user))

    get "/api/v1/crew/crew_rosters/#{other.id}", headers: headers

    expect(response).to have_http_status(:not_found)
  end

  it 'requires authentication' do
    get "/api/v1/crew/crew_rosters/#{roster.id}"

    expect(response).to have_http_status(:unauthorized)
  end
end
