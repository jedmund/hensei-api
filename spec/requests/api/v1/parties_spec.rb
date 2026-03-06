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
      expect(results.first).to include('favorited' => true)
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
