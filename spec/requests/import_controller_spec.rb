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

  # Load raw deck JSON from fixture and wrap it under the "import" key.
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
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('shortcode')
      end
    end

    context 'with invalid JSON' do
      it 'returns a bad request error' do
        post '/api/v1/import', params: 'this is not json', headers: headers
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Invalid JSON data')
      end
    end

    context 'with missing required fields in transformed data' do
      it 'returns unprocessable entity error' do
        # Here we simulate missing required fields by sending an import hash
        # where the 'deck' key is present but missing required subkeys.
        invalid_data = { 'import' => { 'deck' => { 'name' => '', 'pc' => nil } } }.to_json
        post '/api/v1/import', params: invalid_data, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Invalid deck data')
      end
    end

    context 'when an error occurs during processing' do
      it 'returns unprocessable entity status with error details' do
        # Stub the transformer to raise an error when transform is called.
        allow_any_instance_of(Processors::CharacterProcessor)
          .to receive(:process).and_raise(StandardError.new('Error processing import'))
        allow_any_instance_of(Processors::WeaponProcessor)
          .to receive(:process).and_raise(StandardError.new('Error processing import'))
        allow_any_instance_of(Processors::SummonProcessor)
          .to receive(:process).and_raise(StandardError.new('Error processing import'))
        allow_any_instance_of(Processors::JobProcessor)
          .to receive(:process).and_raise(StandardError.new('Error processing import'))
        post '/api/v1/import', params: valid_deck_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Error processing import')
      end
    end
  end
end
