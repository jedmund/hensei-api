# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Wonders API', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:other_headers) { auth_headers(other_user) }
  let(:json_headers) { { 'Content-Type' => 'application/json' } }

  let(:seal) { create(:wonder, :seal) }
  let(:symbolum) { create(:wonder, :symbolum) }
  let(:fixed) { create(:wonder) }

  def auth_headers(for_user)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: for_user.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end

  def body
    response.parsed_body
  end

  describe 'GET /api/v1/wonders' do
    before { seed_wonder_catalogue! }

    it 'returns the catalogue with effects, level bonuses and caps, publicly cacheable' do
      get '/api/v1/wonders'

      expect(response).to have_http_status(:ok)
      expect(response.headers['Cache-Control']).to include('public')
      expect(body['categories'].size).to eq(7)
      expect(body['categories'].find { |c| c['granblue_id'] == '4' })
        .to include('name' => { 'en' => 'Crucible Seal', 'ja' => '神滅の印章' }, 'category_type' => 2, 'sort_order' => 4)
      expect(body['wonders'].size).to eq(57)

      seal = body['wonders'].find { |w| w['granblue_id'] == '9008' }
      expect(seal).to include('kind' => 'leveled', 'element' => 2, 'max_level' => 20, 'max_evolution' => 3,
                              'battle_relevant' => true, 'hidden_in_unite_and_fight' => true, 'sort_order' => 2,
                              'effects' => [])
      expect(seal['level_bonuses'].first).to eq('level' => 1, 'stat' => 'fire_resistance', 'value' => 5)
      expect(seal['level_bonuses'].pluck('value')).to all(be_a(Integer))
      expect(seal['evolution_caps'].first).to eq('evolution' => 0, 'max_level' => 10)
      expect(seal['category_id']).to eq(body['categories'].find { |c| c['granblue_id'] == '4' }['id'])
    end

    it 'gives fixed effects in both languages, falling back to EN' do
      get '/api/v1/wonders'

      ring = body['wonders'].find { |w| w['granblue_id'] == '2003' }
      expect(ring['effects'].first).to eq('action_id' => 200_301, 'position' => 1,
                                          'text' => { 'en' => "Gives a 30% boost to dark allies' HP.",
                                                      'ja' => '闇属性キャラのHPが30％UPする。' })
      shrimp = body['wonders'].find { |w| w['granblue_id'] == '9004' }
      expect(shrimp['name']).to eq('en' => 'Premium FRIED SHRIMP', 'ja' => 'Premium FRIED SHRIMP')
      expect(shrimp['effects'].first['action_id']).to be_nil
    end
  end

  describe 'GET /api/v1/users/:user_id/collection/wonders' do
    let!(:owned) { create(:collection_wonder, user: user, wonder: seal, level: 20, evolution: 3) }

    before { create(:collection_wonder, user: other_user, wonder: seal, level: 1) }

    it "returns the user's Wonders with computed bonuses" do
      get "/api/v1/users/#{user.id}/collection/wonders", headers: headers

      expect(response).to have_http_status(:ok)
      expect(body['wonders'].size).to eq(1)
      expect(body['wonders'].first).to eq(
        'id' => owned.id, 'wonder_id' => seal.id, 'granblue_id' => seal.granblue_id, 'active' => true,
        'level' => 20, 'evolution' => 3, 'possession' => nil, 'image' => "#{seal.granblue_id}_20",
        'bonuses' => [{ 'stat' => 'fire_resistance', 'value' => 10 }, { 'stat' => 'def', 'value' => 12 },
                      { 'stat' => 'double_attack_rate', 'value' => 6 }, { 'stat' => 'healing_cap', 'value' => 12 },
                      { 'stat' => 'debuff_resistance', 'value' => 10 }, { 'stat' => 'triple_attack_rate', 'value' => 7 },
                      { 'stat' => 'debuff_success_rate', 'value' => 5 }]
      )
    end

    it 'shows a public collection to visitors' do
      user.update!(collection_privacy: :everyone)

      get "/api/v1/users/#{user.id}/collection/wonders"

      expect(response).to have_http_status(:ok)
    end

    it 'hides a private collection from another user' do
      user.update!(collection_privacy: :private_collection)

      get "/api/v1/users/#{user.id}/collection/wonders", headers: other_headers

      expect(response).to have_http_status(:forbidden)
    end

    it 'shows a private collection to its owner' do
      user.update!(collection_privacy: :private_collection)

      get "/api/v1/users/#{user.id}/collection/wonders", headers: headers

      expect(response).to have_http_status(:ok)
    end

    it 'shows a crew-only collection to a crewmate only' do
      user.update!(collection_privacy: :crew_only)

      get "/api/v1/users/#{user.id}/collection/wonders", headers: other_headers
      expect(response).to have_http_status(:forbidden)

      crew = create(:crew)
      create(:crew_membership, crew: crew, user: user)
      create(:crew_membership, crew: crew, user: other_user)

      get "/api/v1/users/#{user.id}/collection/wonders", headers: other_headers
      expect(response).to have_http_status(:ok)
    end

    it 'hides a crew-only collection from visitors' do
      user.update!(collection_privacy: :crew_only)

      get "/api/v1/users/#{user.id}/collection/wonders"

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /api/v1/collection/wonders' do
    it 'adds a Wonder to the current user, ignoring a user_id' do
      post '/api/v1/collection/wonders',
           params: { collection_wonder: { wonder_id: symbolum.id, possession: 835, active: false,
                                          user_id: other_user.id } }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      expect(body).to include('granblue_id' => '9015', 'possession' => 835, 'active' => false, 'image' => '9015',
                              'bonuses' => [{ 'stat' => 'dmg_amplify', 'value' => 3.3 }])
      expect(user.collection_wonders.count).to eq(1)
      expect(other_user.collection_wonders.count).to eq(0)
    end

    it 'rejects a level above the evolution cap' do
      post '/api/v1/collection/wonders',
           params: { collection_wonder: { wonder_id: seal.id, level: 15, evolution: 0 } }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(body['errors']).to have_key('level')
    end

    it 'rejects a Wonder already in the collection' do
      create(:collection_wonder, user: user, wonder: fixed)

      post '/api/v1/collection/wonders', params: { collection_wonder: { wonder_id: fixed.id } }.to_json,
                                         headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 404 for an unknown Wonder' do
      post '/api/v1/collection/wonders', params: { collection_wonder: { wonder_id: SecureRandom.uuid } }.to_json,
                                         headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'requires a signed-in user' do
      post '/api/v1/collection/wonders', params: { collection_wonder: { wonder_id: fixed.id } }.to_json,
                                         headers: json_headers

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT and DELETE /api/v1/collection/wonders/:id' do
    let!(:mine) { create(:collection_wonder, user: user, wonder: seal, level: 10, evolution: 0) }
    let!(:theirs) { create(:collection_wonder, user: other_user, wonder: seal, level: 10, evolution: 0) }

    it 'updates my row' do
      put "/api/v1/collection/wonders/#{mine.id}",
          params: { collection_wonder: { level: 20, evolution: 3, active: false } }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(body).to include('level' => 20, 'evolution' => 3, 'active' => false, 'image' => "#{seal.granblue_id}_20")
    end

    it 'does not move a row to another Wonder' do
      put "/api/v1/collection/wonders/#{mine.id}",
          params: { collection_wonder: { wonder_id: fixed.id, level: 5 } }.to_json, headers: headers

      expect(mine.reload).to have_attributes(wonder_id: seal.id, level: 5)
    end

    it "can't update someone else's row" do
      put "/api/v1/collection/wonders/#{theirs.id}",
          params: { collection_wonder: { level: 1 } }.to_json, headers: headers

      expect(response).to have_http_status(:not_found)
      expect(theirs.reload.level).to eq(10)
    end

    it "can't delete someone else's row" do
      delete "/api/v1/collection/wonders/#{theirs.id}", headers: headers

      expect(response).to have_http_status(:not_found)
      expect(CollectionWonder.exists?(theirs.id)).to be(true)
    end

    it 'deletes my row' do
      delete "/api/v1/collection/wonders/#{mine.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(CollectionWonder.exists?(mine.id)).to be(false)
    end
  end

  describe 'POST /api/v1/collection/wonders/import' do
    before { seed_wonder_catalogue! }

    it 'imports the raw capture for the current user' do
      data = wonder_capture('en')
      data.first['item'] << { 'item_id' => '9999', 'name' => 'Not In Catalogue', 'set_flg' => '1' }

      post '/api/v1/collection/wonders/import', params: { data: data, lang: 'en' }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(body).to eq('success' => true, 'created' => 51, 'updated' => 0,
                         'skipped' => [{ 'granblue_id' => '9999', 'name' => 'Not In Catalogue',
                                         'reason' => 'unknown_wonder' }],
                         'warnings' => [])
      expect(user.collection_wonders.count).to eq(51)
      expect(other_user.collection_wonders.count).to eq(0)
    end

    it 'rejects a missing or malformed payload' do
      post '/api/v1/collection/wonders/import', params: { lang: 'en' }.to_json, headers: headers
      expect(response).to have_http_status(:bad_request)

      post '/api/v1/collection/wonders/import', params: { data: { item: [] } }.to_json, headers: headers
      expect(response).to have_http_status(:bad_request)
    end

    it 'requires a signed-in user' do
      post '/api/v1/collection/wonders/import', params: { data: wonder_capture('en') }.to_json, headers: json_headers

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /api/v1/parties/:id/wonders' do
    let(:party) { create(:party, user: user) }
    let(:others_party) { create(:party, user: other_user) }
    let(:anon_party) do
      create(:party, user: nil).tap { |p| p.update_columns(edit_key: 'anonsecret') }
    end
    let(:list) do
      [{ wonder_id: seal.id, level: 18, evolution: 2 }, { wonder_id: symbolum.id, possession: 900 },
       { wonder_id: fixed.id }]
    end

    it "replaces the owner's team Wonders" do
      create(:party_wonder, party: party, wonder: create(:wonder))

      put "/api/v1/parties/#{party.id}/wonders", params: { wonders: list }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(body['wonders'].pluck('wonder_id')).to contain_exactly(seal.id, symbolum.id, fixed.id)
      expect(body['wonders'].first.keys).not_to include('active')
      symbolum_row = body['wonders'].find { |w| w['wonder_id'] == symbolum.id }
      expect(symbolum_row['bonuses']).to eq([{ 'stat' => 'dmg_amplify', 'value' => 4 }])
      expect(party.party_wonders.count).to eq(3)
    end

    it "keeps Symbolum's image while its count is unchanged" do
      create(:party_wonder, party: party, wonder: symbolum, possession: 900, image: '9015_10')

      put "/api/v1/parties/#{party.id}/wonders", params: { wonders: list }.to_json, headers: headers

      expect(party.party_wonders.find_by(wonder: symbolum).image).to eq('9015_10')
    end

    it 'clears the list' do
      create(:party_wonder, party: party, wonder: fixed)

      put "/api/v1/parties/#{party.id}/wonders", params: { wonders: [] }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(party.party_wonders.count).to eq(0)
    end

    it "can't write to someone else's party" do
      put "/api/v1/parties/#{others_party.id}/wonders", params: { wonders: list }.to_json, headers: headers

      expect(response).to have_http_status(:unauthorized)
      expect(others_party.party_wonders.count).to eq(0)
    end

    it 'requires the edit key for an anonymous party' do
      put "/api/v1/parties/#{anon_party.id}/wonders", params: { wonders: list }.to_json,
                                                      headers: json_headers.merge('X-Edit-Key' => 'wrong')
      expect(response).to have_http_status(:unauthorized)

      put "/api/v1/parties/#{anon_party.id}/wonders", params: { wonders: list }.to_json,
                                                      headers: json_headers.merge('X-Edit-Key' => 'anonsecret')
      expect(response).to have_http_status(:ok)
      expect(anon_party.party_wonders.count).to eq(3)
    end

    it 'ignores ownership fields' do
      entries = [{ wonder_id: fixed.id, party_id: others_party.id, user_id: other_user.id }]

      put "/api/v1/parties/#{party.id}/wonders", params: { wonders: entries, party_id: others_party.id }.to_json,
                                                 headers: headers

      expect(response).to have_http_status(:ok)
      expect(party.party_wonders.count).to eq(1)
      expect(others_party.party_wonders.count).to eq(0)
    end

    it 'rejects unknown or repeated Wonders and non-lists' do
      put "/api/v1/parties/#{party.id}/wonders", params: { wonders: [{ wonder_id: SecureRandom.uuid }] }.to_json,
                                                 headers: headers
      expect(response).to have_http_status(:unprocessable_content)

      put "/api/v1/parties/#{party.id}/wonders",
          params: { wonders: [{ wonder_id: fixed.id }, { wonder_id: fixed.id }] }.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_content)

      put "/api/v1/parties/#{party.id}/wonders", params: { wonders: 'x' }.to_json, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects invalid levels and leaves the list as it was' do
      create(:party_wonder, party: party, wonder: fixed)

      put "/api/v1/parties/#{party.id}/wonders",
          params: { wonders: [{ wonder_id: seal.id, level: 20, evolution: 0 }] }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(party.party_wonders.reload.map(&:wonder_id)).to eq([fixed.id])
    end

    it 'returns 404 for an unknown party' do
      put "/api/v1/parties/#{SecureRandom.uuid}/wonders", params: { wonders: [] }.to_json, headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'the party JSON' do
    it 'includes the Wonders snapshotted at creation' do
      create(:collection_wonder, user: user, wonder: seal, level: 20, evolution: 3)

      post '/api/v1/parties', params: { party: { name: 'Wonders team' } }.to_json, headers: headers

      expect(response).to have_http_status(:created)
      expect(body.dig('party', 'wonders')).to contain_exactly(
        include('wonder_id' => seal.id, 'level' => 20, 'image' => "#{seal.granblue_id}_20")
      )

      get "/api/v1/parties/#{body.dig('party', 'shortcode')}", headers: other_headers
      expect(body.dig('party', 'wonders').size).to eq(1)
    end

    it 'shows Wonders on a public team even when the owner collection is private' do
      user.update!(collection_privacy: :private_collection)
      party = create(:party, user: user)
      create(:party_wonder, party: party, wonder: fixed)

      get "/api/v1/parties/#{party.shortcode}", headers: other_headers

      expect(body.dig('party', 'wonders').pluck('wonder_id')).to eq([fixed.id])
    end
  end
end
