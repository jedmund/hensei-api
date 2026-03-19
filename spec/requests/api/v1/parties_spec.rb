# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Parties API', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  describe 'POST /api/v1/parties' do
    context 'with valid attributes' do
      let(:valid_attributes) do
        {
          party: {
            name: 'Test Party',
            description: 'A party for testing',
            raid_id: nil,
            visibility: 1,
            full_auto: false,
            auto_guard: false,
            charge_attack: true,
            clear_time: 500,
            button_count: 3,
            turn_count: 4,
            chain_count: 2
          }
        }
      end

      it 'creates a new party and returns status created' do
        expect do
          post '/api/v1/parties', params: valid_attributes.to_json, headers: headers
        end.to change(Party, :count).by(1)
        expect(response).to have_http_status(:created)
        expect(response.parsed_body.dig('party', 'name')).to eq('Test Party')
      end
    end
  end

  describe 'GET /api/v1/parties/:id' do
    let!(:party) { create(:party, user: user, name: 'Visible Party', visibility: 1) }

    context 'when the party is public or owned' do
      it 'returns the party details' do
        get "/api/v1/parties/#{party.shortcode}", headers: headers
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.dig('party', 'name')).to eq('Visible Party')
      end
    end

    context 'when the party is private and not owned' do
      let!(:private_party) { create(:party, user: create(:user), visibility: 3, name: 'Private Party') }

      it 'returns unauthorized' do
        get "/api/v1/parties/#{private_party.shortcode}", headers: headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'viewer_collection' do
      let(:weapon) { create(:weapon, granblue_id: '1040099001') }
      let(:character) { create(:character, granblue_id: '3040099001') }
      let(:summon) { create(:summon, granblue_id: '2040099001') }

      let!(:party_with_items) do
        p = create(:party, user: create(:user), visibility: 1)
        create(:grid_weapon, party: p, weapon: weapon, position: 0)
        create(:grid_character, party: p, character: character, position: 0)
        create(:grid_summon, party: p, summon: summon, position: 1)
        p.reload
      end

      it 'includes matching collection items for the viewing user' do
        create(:collection_weapon, user: user, weapon: weapon, uncap_level: 4)
        create(:collection_character, user: user, character: character, uncap_level: 5)
        create(:collection_summon, user: user, summon: summon, uncap_level: 3)

        get "/api/v1/parties/#{party_with_items.shortcode}", headers: headers

        expect(response).to have_http_status(:ok)
        vc = response.parsed_body.dig('party', 'viewer_collection')
        expect(vc).to be_present
        expect(vc['characters'].length).to eq(1)
        expect(vc['characters'][0]['uncap_level']).to eq(5)
        expect(vc['weapons'].length).to eq(1)
        expect(vc['weapons'][0]['uncap_level']).to eq(4)
        expect(vc['summons'].length).to eq(1)
        expect(vc['summons'][0]['uncap_level']).to eq(3)
      end

      it 'returns all copies when viewer owns multiple items with the same granblue_id' do
        create(:collection_weapon, user: user, weapon: weapon, uncap_level: 3)
        create(:collection_weapon, user: user, weapon: weapon, uncap_level: 4)
        create(:collection_weapon, user: user, weapon: weapon, uncap_level: 5)

        get "/api/v1/parties/#{party_with_items.shortcode}", headers: headers

        vc = response.parsed_body.dig('party', 'viewer_collection')
        expect(vc['weapons'].length).to eq(3)
        uncap_levels = vc['weapons'].map { |w| w['uncap_level'] }
        expect(uncap_levels).to contain_exactly(3, 4, 5)
      end

      it 'omits viewer_collection when not logged in' do
        get "/api/v1/parties/#{party_with_items.shortcode}"

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.dig('party', 'viewer_collection')).to be_nil
      end

      it 'returns empty arrays when viewer has no matching collection items' do
        get "/api/v1/parties/#{party_with_items.shortcode}", headers: headers

        vc = response.parsed_body.dig('party', 'viewer_collection')
        expect(vc).to be_present
        expect(vc['characters']).to eq([])
        expect(vc['weapons']).to eq([])
        expect(vc['summons']).to eq([])
      end

      it 'excludes collection items that do not match any party granblue_id' do
        unrelated_weapon = create(:weapon, granblue_id: '1040099999')
        create(:collection_weapon, user: user, weapon: unrelated_weapon)
        create(:collection_weapon, user: user, weapon: weapon)

        get "/api/v1/parties/#{party_with_items.shortcode}", headers: headers

        vc = response.parsed_body.dig('party', 'viewer_collection')
        expect(vc['weapons'].length).to eq(1)
        expect(vc['weapons'][0]['weapon']['granblue_id']).to eq('1040099001')
      end

      it 'returns viewer_collection regardless of viewer privacy setting' do
        user.update!(collection_privacy: :private_collection)
        create(:collection_weapon, user: user, weapon: weapon)

        get "/api/v1/parties/#{party_with_items.shortcode}", headers: headers

        vc = response.parsed_body.dig('party', 'viewer_collection')
        expect(vc).to be_present
        expect(vc['weapons'].length).to eq(1)
      end

      it 'returns empty arrays when party has no grid items' do
        empty_party = create(:party, user: create(:user), visibility: 1)

        get "/api/v1/parties/#{empty_party.shortcode}", headers: headers

        vc = response.parsed_body.dig('party', 'viewer_collection')
        expect(vc).to be_present
        expect(vc['characters']).to eq([])
        expect(vc['weapons']).to eq([])
        expect(vc['summons']).to eq([])
      end

      it 'includes expected fields in collection weapon items' do
        create(:collection_weapon, user: user, weapon: weapon, uncap_level: 4)

        get "/api/v1/parties/#{party_with_items.shortcode}", headers: headers

        weapon_item = response.parsed_body.dig('party', 'viewer_collection', 'weapons', 0)
        expect(weapon_item).to include('uncap_level' => 4, 'transcendence_step' => 0)
        expect(weapon_item).to have_key('weapon')
      end

      it 'includes expected fields in collection character items' do
        create(:collection_character, user: user, character: character, uncap_level: 5, perpetuity: true)

        get "/api/v1/parties/#{party_with_items.shortcode}", headers: headers

        char_item = response.parsed_body.dig('party', 'viewer_collection', 'characters', 0)
        expect(char_item).to include('uncap_level' => 5, 'perpetuity' => true)
        expect(char_item).to have_key('character')
      end

      it 'includes expected fields in collection summon items' do
        create(:collection_summon, user: user, summon: summon, uncap_level: 4)

        get "/api/v1/parties/#{party_with_items.shortcode}", headers: headers

        summon_item = response.parsed_body.dig('party', 'viewer_collection', 'summons', 0)
        expect(summon_item).to include('uncap_level' => 4, 'transcendence_step' => 0)
        expect(summon_item).to have_key('summon')
      end
    end

    context 'source_collection' do
      let(:weapon) { create(:weapon, granblue_id: '1040098001') }
      let(:source_user) { create(:user, collection_privacy: :everyone) }

      it 'includes source_collection when party has a collection source user' do
        party_with_source = create(:party, user: create(:user), visibility: 1, collection_source_user: source_user)
        create(:grid_weapon, party: party_with_source, weapon: weapon, position: 0)
        create(:collection_weapon, user: source_user, weapon: weapon, uncap_level: 5)

        get "/api/v1/parties/#{party_with_source.shortcode}", headers: headers

        sc = response.parsed_body.dig('party', 'source_collection')
        expect(sc).to be_present
        expect(sc['weapons'].length).to eq(1)
        expect(sc['weapons'][0]['uncap_level']).to eq(5)
      end

      it 'omits source_collection when source user collection is private' do
        private_source = create(:user, collection_privacy: :private_collection)
        party_with_source = create(:party, user: create(:user), visibility: 1, collection_source_user: private_source)
        create(:grid_weapon, party: party_with_source, weapon: weapon, position: 0)
        create(:collection_weapon, user: private_source, weapon: weapon)

        get "/api/v1/parties/#{party_with_source.shortcode}", headers: headers

        expect(response.parsed_body.dig('party', 'source_collection')).to be_nil
      end

      it 'omits source_collection when viewer is the source user' do
        party_with_source = create(:party, user: create(:user), visibility: 1, collection_source_user: user)
        create(:grid_weapon, party: party_with_source, weapon: weapon, position: 0)
        create(:collection_weapon, user: user, weapon: weapon)

        get "/api/v1/parties/#{party_with_source.shortcode}", headers: headers

        expect(response.parsed_body.dig('party', 'source_collection')).to be_nil
        # But viewer_collection should still be present
        expect(response.parsed_body.dig('party', 'viewer_collection')).to be_present
      end

      it 'omits source_collection when party has no collection source' do
        party_no_source = create(:party, user: create(:user), visibility: 1)
        create(:grid_weapon, party: party_no_source, weapon: weapon, position: 0)

        get "/api/v1/parties/#{party_no_source.shortcode}", headers: headers

        expect(response.parsed_body.dig('party', 'source_collection')).to be_nil
      end
    end
  end

  describe 'PUT /api/v1/parties/:id' do
    let!(:party) { create(:party, user: user, name: 'Old Name') }
    let(:update_attributes) do
      { party: { name: 'New Name', description: 'Updated description' } }
    end

    it 'updates the party and persists changes' do
      put "/api/v1/parties/#{party.id}", params: update_attributes.to_json, headers: headers
      expect(response).to have_http_status(:ok)

      party_json = response.parsed_body['party']
      expect(party_json).to include('name' => 'New Name', 'description' => 'Updated description')
      expect(party.reload.name).to eq('New Name')
      expect(party.description).to eq('Updated description')
    end

    it 'rejects update by non-owner' do
      other_user = create(:user)
      other_token = Doorkeeper::AccessToken.create!(resource_owner_id: other_user.id, expires_in: 30.days, scopes: 'public')
      other_headers = { 'Authorization' => "Bearer #{other_token.token}", 'Content-Type' => 'application/json' }

      put "/api/v1/parties/#{party.id}", params: update_attributes.to_json, headers: other_headers
      expect(response).to have_http_status(:unauthorized)
      expect(party.reload.name).to eq('Old Name')
    end
  end

  describe 'DELETE /api/v1/parties/:id' do
    let!(:party) { create(:party, user: user) }

    it 'destroys the party' do
      expect {
        delete "/api/v1/parties/#{party.id}", headers: headers
      }.to change(Party, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it 'rejects deletion by non-owner' do
      other_user = create(:user)
      other_token = Doorkeeper::AccessToken.create!(resource_owner_id: other_user.id, expires_in: 30.days, scopes: 'public')
      other_headers = { 'Authorization' => "Bearer #{other_token.token}", 'Content-Type' => 'application/json' }

      expect {
        delete "/api/v1/parties/#{party.id}", headers: other_headers
      }.not_to change(Party, :count)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'anonymous party management' do
    let!(:anon_party) { create(:party, user: nil, edit_key: 'anonsecret', name: 'Anon Party') }
    let(:anon_headers) { { 'Content-Type' => 'application/json', 'X-Edit-Key' => 'anonsecret' } }

    it 'allows updating an anonymous party with correct edit_key' do
      put "/api/v1/parties/#{anon_party.id}",
          params: { party: { name: 'Updated Anon' } }.to_json,
          headers: anon_headers
      expect(response).to have_http_status(:ok)
      expect(anon_party.reload.name).to eq('Updated Anon')
    end

    it 'rejects updating an anonymous party with wrong edit_key' do
      wrong_headers = { 'Content-Type' => 'application/json', 'X-Edit-Key' => 'wrong' }
      put "/api/v1/parties/#{anon_party.id}",
          params: { party: { name: 'Hacked' } }.to_json,
          headers: wrong_headers
      expect(response).to have_http_status(:unauthorized)
      expect(anon_party.reload.name).to eq('Anon Party')
    end

    it 'allows deleting an anonymous party with correct edit_key' do
      expect {
        delete "/api/v1/parties/#{anon_party.id}", headers: anon_headers
      }.to change(Party, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it 'rejects deleting an anonymous party with wrong edit_key' do
      wrong_headers = { 'Content-Type' => 'application/json', 'X-Edit-Key' => 'wrong' }
      expect {
        delete "/api/v1/parties/#{anon_party.id}", headers: wrong_headers
      }.not_to change(Party, :count)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'prevents a logged-in user from editing an anonymous party' do
      put "/api/v1/parties/#{anon_party.id}",
          params: { party: { name: 'Stolen' } }.to_json,
          headers: headers
      expect(response).to have_http_status(:unauthorized)
      expect(anon_party.reload.name).to eq('Anon Party')
    end
  end

  describe 'POST /api/v1/parties/migrate' do
    let!(:anon_party1) { create(:party, user: nil, name: 'Anon 1') }
    let!(:anon_party2) { create(:party, user: nil, name: 'Anon 2') }

    before do
      anon_party1.update_columns(edit_key: 'key1')
      anon_party2.update_columns(edit_key: 'key2')
    end

    it 'migrates anonymous parties with valid edit keys' do
      post '/api/v1/parties/migrate',
           params: { parties: [
             { shortcode: anon_party1.shortcode, edit_key: 'key1' },
             { shortcode: anon_party2.shortcode, edit_key: 'key2' }
           ] }.to_json,
           headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['migrated_count']).to eq(2)
      expect(json['results'].map { |r| r['status'] }).to all(eq('migrated'))

      anon_party1.reload
      expect(anon_party1.user_id).to eq(user.id)
      expect(anon_party1.edit_key).to be_nil
    end

    it 'rejects unauthenticated requests' do
      post '/api/v1/parties/migrate',
           params: { parties: [{ shortcode: anon_party1.shortcode, edit_key: 'key1' }] }.to_json,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns already_claimed for parties with a user' do
      claimed_party = create(:party, user: user, name: 'Claimed')

      post '/api/v1/parties/migrate',
           params: { parties: [{ shortcode: claimed_party.shortcode, edit_key: 'anything' }] }.to_json,
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['results'].first['status']).to eq('already_claimed')
    end

    it 'returns invalid_key for wrong edit key' do
      post '/api/v1/parties/migrate',
           params: { parties: [{ shortcode: anon_party1.shortcode, edit_key: 'wrong' }] }.to_json,
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['results'].first['status']).to eq('invalid_key')
      expect(anon_party1.reload.user_id).to be_nil
    end

    it 'returns not_found for bad shortcode' do
      post '/api/v1/parties/migrate',
           params: { parties: [{ shortcode: 'NOPE99', edit_key: 'key1' }] }.to_json,
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['results'].first['status']).to eq('not_found')
    end

    it 'falls back to server-stored edit keys when no parties param' do
      user.user_edit_keys.create!(edit_key: 'key1', shortcode: anon_party1.shortcode)

      post '/api/v1/parties/migrate', params: {}.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['migrated_count']).to eq(1)
      expect(user.user_edit_keys.count).to eq(0)
    end

    it 'cleans up deposited edit keys after migration' do
      user.user_edit_keys.create!(edit_key: 'key1', shortcode: anon_party1.shortcode)

      post '/api/v1/parties/migrate',
           params: { parties: [{ shortcode: anon_party1.shortcode, edit_key: 'key1' }] }.to_json,
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(user.user_edit_keys.count).to eq(0)
    end
  end

  describe 'POST /api/v1/parties/preview_migrate' do
    let!(:anon_party1) { create(:party, user: nil, name: 'Anon 1') }
    let!(:anon_party2) { create(:party, user: nil, name: 'Anon 2') }

    before do
      anon_party1.update_columns(edit_key: 'key1')
      anon_party2.update_columns(edit_key: 'key2')
    end

    it 'returns preview data for valid edit keys without modifying parties' do
      post '/api/v1/parties/preview_migrate',
           params: { parties: [
             { shortcode: anon_party1.shortcode, edit_key: 'key1' },
             { shortcode: anon_party2.shortcode, edit_key: 'key2' }
           ] }.to_json,
           headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['parties'].length).to eq(2)
      expect(json['parties'].map { |r| r['status'] }).to all(eq('ready'))
      expect(json['parties'].first['party']).to be_present

      anon_party1.reload
      expect(anon_party1.user_id).to be_nil
      expect(anon_party1.edit_key).to eq('key1')
    end

    it 'returns already_claimed for parties that already have a user_id' do
      claimed_party = create(:party, user: user, name: 'Claimed')

      post '/api/v1/parties/preview_migrate',
           params: { parties: [{ shortcode: claimed_party.shortcode, edit_key: 'anything' }] }.to_json,
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['parties'].first['status']).to eq('already_claimed')
      expect(response.parsed_body['parties'].first['party']).to be_present
    end

    it 'returns not_found for bad shortcode' do
      post '/api/v1/parties/preview_migrate',
           params: { parties: [{ shortcode: 'NOPE99', edit_key: 'key1' }] }.to_json,
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['parties'].first['status']).to eq('not_found')
      expect(response.parsed_body['parties'].first['party']).to be_nil
    end

    it 'returns invalid_key for wrong edit key' do
      post '/api/v1/parties/preview_migrate',
           params: { parties: [{ shortcode: anon_party1.shortcode, edit_key: 'wrong' }] }.to_json,
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['parties'].first['status']).to eq('invalid_key')
      expect(response.parsed_body['parties'].first['party']).to be_nil
    end

    it 'requires authentication' do
      post '/api/v1/parties/preview_migrate',
           params: { parties: [{ shortcode: anon_party1.shortcode, edit_key: 'key1' }] }.to_json,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/parties/:id/remix' do
    let!(:party) { create(:party, user: user, name: 'Original Party') }
    let(:remix_params) { { party: { local_id: party.local_id } } }

    it 'creates a remixed copy of the party' do
      post "/api/v1/parties/#{party.shortcode}/remix", params: remix_params.to_json, headers: headers
      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig('party', 'source_party', 'id')).to eq(party.id)
    end
  end

  describe 'GET /api/v1/parties' do
    context 'with pagination' do
      before { create_list(:party, 3, user: user, visibility: 1) }

      it 'returns results and meta with count' do
        get '/api/v1/parties', headers: headers
        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        expect(json['results']).to be_an(Array)
        expect(json.dig('meta', 'count')).to be_a(Integer)
      end
    end

    context 'with default filters' do
      let!(:good_party) do
        create(:party, user: user, weapons_count: 5, characters_count: 4, summons_count: 2, visibility: 1)
      end
      let!(:bad_party) do
        create(:party, user: user, weapons_count: 2, characters_count: 2, summons_count: 1, visibility: 1)
      end

      it 'returns only parties meeting the default thresholds' do
        get '/api/v1/parties', headers: headers
        expect(response).to have_http_status(:ok)

        party_ids = response.parsed_body['results'].map { |p| p['id'] }
        expect(party_ids).to include(good_party.id)
        expect(party_ids).not_to include(bad_party.id)
      end
    end
  end

  describe 'GET /api/v1/parties/favorites' do
    let(:other_user) { create(:user) }
    let!(:party) { create(:party, user: other_user, visibility: 1) }

    before do
      create_list(:grid_character, 3, party: party)
      create_list(:grid_weapon, 5, party: party)
      create_list(:grid_summon, 2, party: party)
      party.reload

      create(:favorite, user: user, party: party)
    end

    it 'lists parties favorited by the current user' do
      get '/api/v1/parties/favorites', headers: headers
      expect(response).to have_http_status(:ok)

      results = response.parsed_body['results']
      expect(results).not_to be_empty
      expect(results.first).to include('shortcode' => party.shortcode)
    end
  end

  describe 'Preview Management Endpoints' do
    let!(:party) { create(:party, user: user, shortcode: 'PREV01', element: 0) }

    describe 'GET /api/v1/parties/:id/preview' do
      before do
        coordinator = instance_double(PreviewService::Coordinator)
        allow(PreviewService::Coordinator).to receive(:new).and_return(coordinator)
        allow(coordinator).to receive(:generation_in_progress?).and_return(false)
        allow(coordinator).to receive(:local_preview_path).and_return('/tmp/fake_preview.png')

        allow_any_instance_of(Api::V1::PartiesController).to receive(:send_file) do |instance, *_args|
          instance.render plain: 'dummy image content', content_type: 'image/png', status: 200
        end
      end

      it 'serves the preview image' do
        get "/api/v1/parties/#{party.shortcode}/preview", headers: headers
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('image/png; charset=utf-8')
        expect(response.body).to eq('dummy image content')
      end
    end

    describe 'GET /api/v1/parties/:id/preview_status' do
      it 'returns the preview state' do
        get "/api/v1/parties/#{party.shortcode}/preview_status", headers: headers
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to have_key('state')
      end
    end

    describe 'POST /api/v1/parties/:id/regenerate_preview' do
      before do
        coordinator = instance_double(PreviewService::Coordinator)
        allow(PreviewService::Coordinator).to receive(:new).and_return(coordinator)
        allow(coordinator).to receive(:force_regenerate).and_return(true)
      end

      it 'accepts the regeneration request' do
        post "/api/v1/parties/#{party.shortcode}/regenerate_preview", headers: headers
        expect(response).to have_http_status(:ok).or have_http_status(:unprocessable_entity)
      end
    end
  end
end
