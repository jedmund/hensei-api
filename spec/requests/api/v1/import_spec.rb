# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ImportController', type: :request do
  let(:user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  let(:raw_deck_data) do
    file_path = Rails.root.join('spec', 'fixtures', 'deck_sample.json')
    JSON.parse(File.read(file_path))
  end
  let(:valid_deck_json) { { 'import' => raw_deck_data }.to_json }

  describe 'POST /api/v1/import' do
    context 'with valid deck data' do
      it 'creates a new party and returns a shortcode' do
        expect {
          post '/api/v1/import', params: valid_deck_json, headers: headers
        }.to change(Party, :count).by(1)
        expect(response).to have_http_status(:created)
        expect(response.parsed_body['shortcode']).to be_present
      end
    end

    context 'with invalid JSON' do
      it 'returns a bad request error' do
        post '/api/v1/import', params: 'this is not json', headers: headers
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['error']).to eq('Invalid JSON data')
      end
    end

    context 'with missing required fields in transformed data' do
      it 'returns unprocessable entity error' do
        invalid_data = { 'import' => { 'deck' => { 'name' => '', 'pc' => nil } } }.to_json
        post '/api/v1/import', params: invalid_data, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Invalid deck data')
      end
    end

    context 'with playlist_ids' do
      let!(:playlist1) { create(:playlist, user: user) }
      let!(:playlist2) { create(:playlist, user: user) }

      it 'adds the imported party to the specified playlists' do
        body = { 'import' => raw_deck_data, 'playlist_ids' => [playlist1.id, playlist2.id] }.to_json

        expect {
          post '/api/v1/import', params: body, headers: headers
        }.to change(PlaylistParty, :count).by(2)

        expect(response).to have_http_status(:created)
        party = Party.find_by(shortcode: response.parsed_body['shortcode'])
        expect(party.playlists).to contain_exactly(playlist1, playlist2)
      end

      it 'ignores playlist IDs belonging to another user' do
        other_user = create(:user)
        other_playlist = create(:playlist, user: other_user)
        body = { 'import' => raw_deck_data, 'playlist_ids' => [playlist1.id, other_playlist.id] }.to_json

        expect {
          post '/api/v1/import', params: body, headers: headers
        }.to change(PlaylistParty, :count).by(1)

        party = Party.find_by(shortcode: response.parsed_body['shortcode'])
        expect(party.playlists).to contain_exactly(playlist1)
      end

      it 'ignores non-existent playlist IDs' do
        body = { 'import' => raw_deck_data, 'playlist_ids' => [playlist1.id, SecureRandom.uuid] }.to_json

        expect {
          post '/api/v1/import', params: body, headers: headers
        }.to change(PlaylistParty, :count).by(1)

        party = Party.find_by(shortcode: response.parsed_body['shortcode'])
        expect(party.playlists).to contain_exactly(playlist1)
      end

      it 'works normally when playlist_ids is not provided' do
        expect {
          post '/api/v1/import', params: valid_deck_json, headers: headers
        }.not_to change(PlaylistParty, :count)

        expect(response).to have_http_status(:created)
      end
    end

    context 'when a processor raises an error' do
      it 'returns unprocessable entity with the error message' do
        failing_processor = instance_double(Processors::JobProcessor)
        allow(Processors::JobProcessor).to receive(:new).and_return(failing_processor)
        allow(failing_processor).to receive(:process).and_raise(StandardError.new('Error processing import'))

        post '/api/v1/import', params: valid_deck_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Import failed due to an unexpected error. Please try again.')
      end
    end
  end
end
