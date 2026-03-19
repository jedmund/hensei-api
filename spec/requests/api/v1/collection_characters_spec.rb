require 'rails_helper'

RSpec.describe 'Collection Characters API', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  let(:character) { create(:character) }
  let(:awakening) { create(:awakening, object_type: 'Character') }

  describe 'GET /api/v1/users/:user_id/collection/characters' do
    let(:character1) { create(:character) }
    let(:character2) { create(:character) }
    let!(:collection_character1) { create(:collection_character, user: user, character: character1, uncap_level: 5) }
    let!(:collection_character2) { create(:collection_character, user: user, character: character2, uncap_level: 3) }
    let!(:other_user_character) { create(:collection_character, user: other_user) }

    it 'returns the current user\'s collection characters' do
      get "/api/v1/users/#{user.id}/collection/characters", headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['characters'].length).to eq(2)
      expect(json['meta']['count']).to eq(2)
    end

    it 'supports pagination' do
      get "/api/v1/users/#{user.id}/collection/characters", params: { page: 1, limit: 1 }, headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['characters'].length).to eq(1)
      expect(json['meta']['total_pages']).to be >= 2
    end

    it 'supports filtering by element' do
      fire_character = create(:character, element: 0)
      create(:collection_character, user: user, character: fire_character)

      get "/api/v1/users/#{user.id}/collection/characters", params: { element: 0 }, headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      characters = json['characters']
      expect(characters.all? { |c| c['character']['element'] == 0 }).to be true
    end

    it 'supports filtering by rarity' do
      ssr_character = create(:character, rarity: 4)
      create(:collection_character, user: user, character: ssr_character)

      get "/api/v1/users/#{user.id}/collection/characters", params: { rarity: 4 }, headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      characters = json['characters']
      expect(characters.all? { |c| c['character']['rarity'] == 4 }).to be true
    end

    it 'supports filtering by both element and rarity' do
      fire_ssr = create(:character, element: 0, rarity: 4)
      water_ssr = create(:character, element: 1, rarity: 4)
      fire_sr = create(:character, element: 0, rarity: 3)

      create(:collection_character, user: user, character: fire_ssr)
      create(:collection_character, user: user, character: water_ssr)
      create(:collection_character, user: user, character: fire_sr)

      get "/api/v1/users/#{user.id}/collection/characters", params: { element: 0, rarity: 4 }, headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      characters = json['characters']
      expect(characters.length).to eq(1)
      expect(characters.first['character']['element']).to eq(0)
      expect(characters.first['character']['rarity']).to eq(4)
    end

    it 'supports filtering by series' do
      grand_series = create(:character_series, :grand)
      grand_char = create(:character)
      create(:character_series_membership, character: grand_char, character_series: grand_series)
      create(:collection_character, user: user, character: grand_char)

      other_char = create(:character)
      create(:collection_character, user: user, character: other_char)

      get "/api/v1/users/#{user.id}/collection/characters",
          params: { series: grand_series.id }, headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['characters'].length).to eq(1)
    end

    it 'returns empty array when filters match nothing' do
      fire_character = create(:character, element: 0, rarity: 4)
      create(:collection_character, user: user, character: fire_character)

      get "/api/v1/users/#{user.id}/collection/characters", params: { element: 1, rarity: 3 }, headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['characters']).to be_empty
    end

    it 'returns forbidden for private collection without authentication' do
      private_user = create(:user, collection_privacy: :private_collection)
      create(:collection_character, user: private_user)

      get "/api/v1/users/#{private_user.id}/collection/characters"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/v1/users/:user_id/collection/characters/:id' do
    let!(:collection_character) { create(:collection_character, user: user, character: character) }

    it 'returns the collection character' do
      get "/api/v1/users/#{user.id}/collection/characters/#{collection_character.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['id']).to eq(collection_character.id)
      expect(json['character']['id']).to eq(character.id)
    end

    it 'returns not found for other user\'s character' do
      other_collection = create(:collection_character, user: other_user)
      get "/api/v1/users/#{user.id}/collection/characters/#{other_collection.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found for non-existent character' do
      get "/api/v1/users/#{user.id}/collection/characters/#{SecureRandom.uuid}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/collection_characters' do
    let(:valid_attributes) do
      {
        collection_character: {
          character_id: character.id,
          uncap_level: 3,
          transcendence_step: 0,
          perpetuity: false,
          awakening_id: awakening.id,
          awakening_level: 5
        }
      }
    end

    it 'creates a new collection character' do
      expect do
        post '/api/v1/collection/characters', params: valid_attributes.to_json, headers: headers
      end.to change(CollectionCharacter, :count).by(1)

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['character']['id']).to eq(character.id)
      expect(json['uncap_level']).to eq(3)
    end

    it 'returns error when character already in collection' do
      create(:collection_character, user: user, character: character)

      expect {
        post '/api/v1/collection/characters', params: valid_attributes.to_json, headers: headers
      }.not_to change(CollectionCharacter, :count)

      expect(response).to have_http_status(:conflict)
      json = response.parsed_body
      expect(json['error']['message']).to include('already exists in your collection')
    end

    it 'returns error with invalid awakening type' do
      weapon_awakening = create(:awakening, object_type: 'Weapon')
      invalid_attributes = valid_attributes.deep_merge(
        collection_character: { awakening_id: weapon_awakening.id }
      )

      expect {
        post '/api/v1/collection/characters', params: invalid_attributes.to_json, headers: headers
      }.not_to change(CollectionCharacter, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      json = response.parsed_body
      expect(json['errors'].to_s).to include('must be a character awakening')
    end

    it 'returns error with invalid transcendence' do
      invalid_attributes = valid_attributes.deep_merge(
        collection_character: { uncap_level: 3, transcendence_step: 5 }
      )

      expect {
        post '/api/v1/collection/characters', params: invalid_attributes.to_json, headers: headers
      }.not_to change(CollectionCharacter, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      json = response.parsed_body
      expect(json['errors'].to_s).to include('requires uncap level 5')
    end
  end

  describe 'PUT /api/v1/collection_characters/:id' do
    let!(:collection_character) { create(:collection_character, user: user, character: character, uncap_level: 3) }

    let(:update_attributes) do
      {
        collection_character: {
          uncap_level: 5,
          transcendence_step: 3,
          ring1: { modifier: 1, strength: 12.5 }
        }
      }
    end

    it 'updates the collection character' do
      put "/api/v1/collection/characters/#{collection_character.id}",
          params: update_attributes.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['uncap_level']).to eq(5)
      expect(json['transcendence_step']).to eq(3)
      expect(json['ring1']['modifier']).to eq(1)
    end

    it 'returns not found for other user\'s character' do
      other_collection = create(:collection_character, user: other_user, uncap_level: 3)
      put "/api/v1/collection/characters/#{other_collection.id}",
          params: update_attributes.to_json, headers: headers

      expect(response).to have_http_status(:not_found)
      expect(other_collection.reload.uncap_level).to eq(3)
    end

    it 'returns error with invalid ring data' do
      invalid_attributes = {
        collection_character: {
          ring1: { modifier: 1, strength: nil }  # Invalid: missing strength
        }
      }

      put "/api/v1/collection/characters/#{collection_character.id}",
          params: invalid_attributes.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = response.parsed_body
      expect(json['errors'].to_s).to include('Ring 1 must have both modifier and strength')
    end
  end

  describe 'DELETE /api/v1/collection_characters/:id' do
    let!(:collection_character) { create(:collection_character, user: user, character: character) }

    it 'deletes the collection character' do
      expect do
        delete "/api/v1/collection/characters/#{collection_character.id}", headers: headers
      end.to change(CollectionCharacter, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'returns not found for other user\'s character' do
      other_collection = create(:collection_character, user: other_user)

      expect do
        delete "/api/v1/collection/characters/#{other_collection.id}", headers: headers
      end.not_to change(CollectionCharacter, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

end