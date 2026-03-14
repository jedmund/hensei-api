# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Substitutions API', type: :request do
  let(:user) { create(:user) }
  let(:party) { create(:party, user: user, edit_key: 'secret') }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(
      resource_owner_id: user.id,
      expires_in: 30.days,
      scopes: 'public'
    )
  end
  let(:headers) do
    {
      'Authorization' => "Bearer #{access_token.token}",
      'Content-Type' => 'application/json'
    }
  end

  let(:character1) { Character.find_by!(granblue_id: '3040087000') }
  let(:character2) { Character.find_by!(granblue_id: '3040036000') }

  let!(:primary_gc) do
    create(:grid_character, party: party, character: character1, position: 0)
  end

  describe 'POST /substitutions' do
    let(:valid_params) do
      {
        substitution: {
          grid_type: 'GridCharacter',
          grid_id: primary_gc.id,
          character_id: character2.id,
          position: 0
        }
      }
    end

    context 'when authorized' do
      it 'creates a substitute grid item and a substitution join record' do
        expect {
          post '/api/v1/substitutions', params: valid_params.to_json, headers: headers
        }.to change(Substitution, :count).by(1)
           .and change(GridCharacter, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['substitution']['position']).to eq(0)
        expect(json['substitution']['grid_character']).to be_present
      end

      it 'does not increment the party characters_count' do
        expect {
          post '/api/v1/substitutions', params: valid_params.to_json, headers: headers
        }.not_to change { party.reload.characters_count }
      end

      it 'rejects an 11th substitution' do
        10.times do |i|
          alt_char = Character.order(:id).offset(i + 2).first
          alt_gc = create(:grid_character, party: party, character: alt_char, position: 0, is_substitute: true)
          Substitution.create!(grid: primary_gc, substitute_grid: alt_gc, position: i)
        end

        post '/api/v1/substitutions', params: valid_params.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when not authorized' do
      let(:other_user) { create(:user) }
      let(:other_token) do
        Doorkeeper::AccessToken.create!(
          resource_owner_id: other_user.id,
          expires_in: 30.days,
          scopes: 'public'
        )
      end
      let(:other_headers) do
        {
          'Authorization' => "Bearer #{other_token.token}",
          'Content-Type' => 'application/json'
        }
      end

      it 'rejects a non-owner' do
        post '/api/v1/substitutions', params: valid_params.to_json, headers: other_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'for an anonymous party' do
      let(:anon_party) { create(:party, user: nil, edit_key: 'anonsecret') }
      let!(:anon_gc) do
        create(:grid_character, party: anon_party, character: character1, position: 0)
      end

      it 'allows creation with a correct edit key' do
        params = {
          substitution: {
            grid_type: 'GridCharacter',
            grid_id: anon_gc.id,
            character_id: character2.id,
            position: 0
          }
        }
        anon_headers = { 'Content-Type' => 'application/json', 'X-Edit-Key' => 'anonsecret' }

        post '/api/v1/substitutions', params: params.to_json, headers: anon_headers
        expect(response).to have_http_status(:created)
      end

      it 'rejects with a wrong edit key' do
        params = {
          substitution: {
            grid_type: 'GridCharacter',
            grid_id: anon_gc.id,
            character_id: character2.id,
            position: 0
          }
        }
        anon_headers = { 'Content-Type' => 'application/json', 'X-Edit-Key' => 'wrongkey' }

        post '/api/v1/substitutions', params: params.to_json, headers: anon_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /substitutions/:id' do
    it 'destroys both the substitution and the substitute grid item' do
      sub_gc = create(:grid_character, party: party, character: character2, position: 0, is_substitute: true)
      substitution = Substitution.create!(grid: primary_gc, substitute_grid: sub_gc, position: 0)

      expect {
        delete "/api/v1/substitutions/#{substitution.id}", headers: headers
      }.to change(Substitution, :count).by(-1)
         .and change(GridCharacter, :count).by(-1)

      expect(response).to have_http_status(:no_content)
      expect(GridCharacter.exists?(primary_gc.id)).to be true
    end
  end

  describe 'PUT /substitutions/:id' do
    it 'reorders a substitution' do
      sub_gc = create(:grid_character, party: party, character: character2, position: 0, is_substitute: true)
      substitution = Substitution.create!(grid: primary_gc, substitute_grid: sub_gc, position: 0)

      put "/api/v1/substitutions/#{substitution.id}",
          params: { substitution: { position: 5 } }.to_json,
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(substitution.reload.position).to eq(5)
    end
  end
end
