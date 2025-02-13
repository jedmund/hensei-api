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
        json = JSON.parse(response.body)
        expect(json['party']['name']).to eq('Test Party')
      end
    end
  end

  describe 'GET /api/v1/parties/:id' do
    let!(:party) { create(:party, user: user, name: 'Visible Party', visibility: 1) }

    context 'when the party is public or owned' do
      it 'returns the party details' do
        get "/api/v1/parties/#{party.shortcode}", headers: headers
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['party']['name']).to eq('Visible Party')
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

    it 'updates the party and returns the updated party' do
      put "/api/v1/parties/#{party.id}", params: update_attributes.to_json, headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['party']['name']).to eq('New Name')
      expect(json['party']['description']).to eq('Updated description')
    end
  end

  describe 'DELETE /api/v1/parties/:id' do
    let!(:party) { create(:party, user: user) }
    it 'destroys the party and returns the destroyed party view' do
      delete "/api/v1/parties/#{party.id}", headers: headers
      expect(response).to have_http_status(:ok)
      expect { party.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'POST /api/v1/parties/:id/remix' do
    let!(:party) { create(:party, user: user, name: 'Original Party') }
    let(:remix_params) { { party: { local_id: party.local_id } } }
    it 'creates a remixed copy of the party' do
      post "/api/v1/parties/#{party.shortcode}/remix", params: remix_params.to_json, headers: headers
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['party']['source_party']['id']).to eq(party.id)
    end
  end

  describe 'GET /api/v1/parties' do
    before { create_list(:party, 3, user: user, visibility: 1) }
    it 'lists parties with pagination' do
      get '/api/v1/parties', headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['results']).to be_an(Array)
      expect(json['meta']).to have_key('count')
    end
  end

  describe 'GET /api/v1/parties/favorites' do
    let(:other_user) { create(:user) }
    let!(:party) { create(:party, user: other_user, visibility: 1) }

    before do
      # Create associated records so that the party meets the default filtering minimums:
      # - At least 3 characters,
      # - At least 5 weapons,
      # - At least 2 summons.
      create_list(:grid_character, 3, party: party)
      create_list(:grid_weapon, 5, party: party)
      create_list(:grid_summon, 2, party: party)
      party.reload # Reload to update counter caches.

      ap "DEBUG: Party counts - characters: #{party.characters_count}, weapons: #{party.weapons_count}, summons: #{party.summons_count}"

      create(:favorite, user: user, party: party)
    end

    before { create(:favorite, user: user, party: party) }

    it 'lists parties favorited by the current user' do
      # Debug: print IDs returned by the join query (this code can be removed later)
      favorite_ids = Party.joins(:favorites).where(favorites: { user_id: user.id }).distinct.pluck(:id)
      ap "DEBUG: Created party id: #{party.id}"
      ap "DEBUG: Favorite party ids: #{favorite_ids.inspect}"

      get '/api/v1/parties/favorites', headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['results']).not_to be_empty
      expect(json['results'].first).to include('favorited' => true)
    end
  end

  describe 'Preview Management Endpoints' do
    let(:user) { create(:user) }
    let!(:party) { create(:party, user: user, shortcode: 'PREV01', element: 0) }
    let(:headers) do
      { 'Authorization' => "Bearer #{Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public').token}",
        'Content-Type' => 'application/json' }
    end

    describe 'GET /api/v1/parties/:id/preview' do
      before do
        # Stub send_file on the correctly namespaced controller.
        allow_any_instance_of(Api::V1::PartiesController).to receive(:send_file) do |instance, *args|
          instance.render plain: 'dummy image content', content_type: 'image/png', status: 200
        end
      end

      it 'serves the preview image (returns 200)' do
        get "/api/v1/parties/#{party.shortcode}/preview", headers: headers
        expect(response).to have_http_status(200)
        expect(response.content_type).to eq('image/png; charset=utf-8')
        expect(response.body).to eq('dummy image content')
      end
    end

    describe 'GET /api/v1/parties/:id/preview_status' do
      it 'returns the preview status of the party' do
        get "/api/v1/parties/#{party.shortcode}/preview_status", headers: headers
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to have_key('state')
      end
    end

    describe 'POST /api/v1/parties/:id/regenerate_preview' do
      it 'forces preview regeneration when requested by the owner' do
        post "/api/v1/parties/#{party.shortcode}/regenerate_preview", headers: headers
        expect(response.status).to(satisfy { |s| [200, 422].include?(s) })
      end
    end
  end

  # Debug block: prints debug info if an example fails.
  after(:each) do |example|
    if example.exception && defined?(response) && response.present?
      error_message = begin
                        JSON.parse(response.body)['exception']
                      rescue JSON::ParserError
                        response.body
                      end

      puts "\nDEBUG: Error Message for '#{example.full_description}': #{error_message}"

      # Parse once and grab the trace safely
      parsed_body = JSON.parse(response.body)
      trace = parsed_body.dig('traces', 'Application Trace')
      ap trace if trace # Only print if trace is not nil
    end
  end
end
