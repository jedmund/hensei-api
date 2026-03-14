# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Substitutions API', type: :request do
  let(:user) { create(:user) }
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

  let(:party) { create(:party, user: user) }
  let(:character) { Character.find_by!(granblue_id: '3040087000') }
  let(:character2) { Character.find_by!(granblue_id: '3040036000') }
  let(:primary_gc) { create(:grid_character, party: party, character: character, position: 0) }

  describe 'POST /api/v1/substitutions' do
    it 'creates a substitution' do
      primary_gc # ensure it exists

      params = {
        substitution: {
          grid_type: 'GridCharacter',
          grid_id: primary_gc.id,
          item_id: character2.id,
          position: 0
        }
      }

      expect {
        post '/api/v1/substitutions', params: params.to_json, headers: headers
      }.to change(Substitution, :count).by(1)
        .and change(GridCharacter, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['substitution']).to be_present
      expect(body['substitution']['position']).to eq(0)
    end

    it 'rejects when not authorized' do
      other_user = create(:user)
      other_party = create(:party, user: other_user)
      other_gc = create(:grid_character, party: other_party, character: character, position: 0)

      params = {
        substitution: {
          grid_type: 'GridCharacter',
          grid_id: other_gc.id,
          item_id: character2.id,
          position: 0
        }
      }

      post '/api/v1/substitutions', params: params.to_json, headers: headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /api/v1/substitutions/:id' do
    it 'updates position' do
      primary_gc
      sub_gc = create(:grid_character, party: party, character: character2, position: 0, is_substitute: true)
      substitution = Substitution.create!(
        grid_type: 'GridCharacter', grid_id: primary_gc.id,
        substitute_grid_type: 'GridCharacter', substitute_grid_id: sub_gc.id,
        position: 0
      )

      put "/api/v1/substitutions/#{substitution.id}",
          params: { substitution: { position: 5 } }.to_json,
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(substitution.reload.position).to eq(5)
    end
  end

  describe 'DELETE /api/v1/substitutions/:id' do
    it 'destroys the substitution and substitute grid item' do
      primary_gc
      sub_gc = create(:grid_character, party: party, character: character2, position: 0, is_substitute: true)
      substitution = Substitution.create!(
        grid_type: 'GridCharacter', grid_id: primary_gc.id,
        substitute_grid_type: 'GridCharacter', substitute_grid_id: sub_gc.id,
        position: 0
      )

      expect {
        delete "/api/v1/substitutions/#{substitution.id}", headers: headers
      }.to change(Substitution, :count).by(-1)

      expect(response).to have_http_status(:no_content)
      expect(GridCharacter.find_by(id: sub_gc.id)).to be_nil
    end
  end
end
