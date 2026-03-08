require 'rails_helper'

RSpec.describe 'Collection Controller API', type: :request do
  let(:user) { create(:user, collection_privacy: :everyone) }
  let(:private_user) { create(:user, collection_privacy: :private_collection) }
  let(:viewer) { create(:user) }

  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: viewer.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  describe 'GET /api/v1/users/:user_id/collection/counts' do
    before do
      create(:collection_character, user: user, character: create(:character))
      create(:collection_character, user: user, character: create(:character))
      create_list(:collection_weapon, 3, user: user)
      create(:collection_summon, user: user)
      create(:collection_artifact, user: user)
    end

    it 'returns counts for all collection types' do
      get "/api/v1/users/#{user.id}/collection/counts", headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['characters']).to eq(2)
      expect(json['weapons']).to eq(3)
      expect(json['summons']).to eq(1)
      expect(json['artifacts']).to eq(1)
    end

    it 'returns zero counts for empty collection' do
      empty_user = create(:user, collection_privacy: :everyone)

      get "/api/v1/users/#{empty_user.id}/collection/counts", headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['characters']).to eq(0)
      expect(json['weapons']).to eq(0)
      expect(json['summons']).to eq(0)
      expect(json['artifacts']).to eq(0)
    end

    it 'returns forbidden for private collection' do
      get "/api/v1/users/#{private_user.id}/collection/counts", headers: headers

      expect(response).to have_http_status(:forbidden)
      json = response.parsed_body
      expect(json['error']).to include('do not have permission')
    end

    it 'allows owner to view their own private collection counts' do
      owner_token = Doorkeeper::AccessToken.create!(
        resource_owner_id: private_user.id,
        expires_in: 30.days,
        scopes: 'public'
      )
      owner_headers = {
        'Authorization' => "Bearer #{owner_token.token}",
        'Content-Type' => 'application/json'
      }

      create(:collection_weapon, user: private_user)

      get "/api/v1/users/#{private_user.id}/collection/counts", headers: owner_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['weapons']).to eq(1)
    end

    it 'returns not found for non-existent user' do
      get "/api/v1/users/#{SecureRandom.uuid}/collection/counts", headers: headers

      expect(response).to have_http_status(:not_found)
      json = response.parsed_body
      expect(json['error']).to include('User not found')
    end
  end

  describe 'GET /api/v1/users/:user_id/collection/granblue_ids' do
    let(:weapon1) { create(:weapon, granblue_id: '1040000100') }
    let(:weapon2) { create(:weapon, granblue_id: '1040000200') }
    let(:character1) { create(:character, granblue_id: '3040000100') }
    let(:summon1) { create(:summon, granblue_id: '2040000100') }

    before do
      create(:collection_weapon, user: user, weapon: weapon1)
      create(:collection_weapon, user: user, weapon: weapon2)
      create(:collection_character, user: user, character: character1)
      create(:collection_summon, user: user, summon: summon1)
    end

    it 'returns granblue IDs for all collection types' do
      get "/api/v1/users/#{user.id}/collection/granblue_ids", headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['weapons']).to contain_exactly('1040000100', '1040000200')
      expect(json['characters']).to contain_exactly('3040000100')
      expect(json['summons']).to contain_exactly('2040000100')
    end

    it 'returns empty arrays for empty collection' do
      empty_user = create(:user, collection_privacy: :everyone)

      get "/api/v1/users/#{empty_user.id}/collection/granblue_ids", headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['weapons']).to be_empty
      expect(json['characters']).to be_empty
      expect(json['summons']).to be_empty
    end

    it 'returns distinct granblue IDs when duplicates exist' do
      # Weapons allow multiple copies of the same weapon
      create(:collection_weapon, user: user, weapon: weapon1)

      get "/api/v1/users/#{user.id}/collection/granblue_ids", headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['weapons']).to contain_exactly('1040000100', '1040000200')
    end

    it 'returns forbidden for private collection' do
      get "/api/v1/users/#{private_user.id}/collection/granblue_ids", headers: headers

      expect(response).to have_http_status(:forbidden)
      json = response.parsed_body
      expect(json['error']).to include('do not have permission')
    end

    it 'returns not found for non-existent user' do
      get "/api/v1/users/#{SecureRandom.uuid}/collection/granblue_ids", headers: headers

      expect(response).to have_http_status(:not_found)
      json = response.parsed_body
      expect(json['error']).to include('User not found')
    end
  end

  describe 'GET /api/v1/users/:user_id/collection/game_ids' do
    let(:weapon1) { create(:weapon, granblue_id: '1040000100') }
    let(:weapon2) { create(:weapon, granblue_id: '1040000200') }
    let(:character1) { create(:character, granblue_id: '3040000100') }
    let(:character2) { create(:character, granblue_id: '3040000200') }
    let(:summon1) { create(:summon, granblue_id: '2040000100') }

    let(:other_user) { create(:user, collection_privacy: :everyone) }

    before do
      create(:collection_weapon, user: user, weapon: weapon1, game_id: '11111')
      create(:collection_weapon, user: user, weapon: weapon2, game_id: '22222')
      create(:collection_character, user: user, character: character1)
      create(:collection_summon, user: user, summon: summon1, game_id: '33333')
      create(:collection_artifact, user: user, game_id: '44444')
    end

    it 'returns all four keys in the response' do
      get "/api/v1/users/#{user.id}/collection/game_ids", headers: headers

      json = response.parsed_body
      expect(json).to have_key('weapons')
      expect(json).to have_key('summons')
      expect(json).to have_key('artifacts')
      expect(json).to have_key('characters')
    end

    it 'returns game_ids (not granblue_ids) for weapons' do
      get "/api/v1/users/#{user.id}/collection/game_ids", headers: headers

      json = response.parsed_body
      # Should return game_ids, not granblue_ids
      expect(json['weapons']).to contain_exactly('11111', '22222')
      expect(json['weapons']).not_to include('1040000100', '1040000200')
    end

    it 'returns game_ids for summons and artifacts' do
      get "/api/v1/users/#{user.id}/collection/game_ids", headers: headers

      json = response.parsed_body
      expect(json['summons']).to contain_exactly('33333')
      expect(json['artifacts']).to contain_exactly('44444')
    end

    it 'returns granblue_ids (not game_ids) for characters' do
      get "/api/v1/users/#{user.id}/collection/game_ids", headers: headers

      json = response.parsed_body
      expect(json['characters']).to contain_exactly('3040000100')
    end

    it 'excludes weapons with null game_id' do
      create(:collection_weapon, user: user, weapon: weapon1, game_id: nil)

      get "/api/v1/users/#{user.id}/collection/game_ids", headers: headers

      json = response.parsed_body
      # Only the two with game_ids, not the null one
      expect(json['weapons']).to contain_exactly('11111', '22222')
    end

    it 'excludes summons with null game_id' do
      create(:collection_summon, user: user, game_id: nil)

      get "/api/v1/users/#{user.id}/collection/game_ids", headers: headers

      json = response.parsed_body
      expect(json['summons']).to contain_exactly('33333')
    end

    it 'excludes artifacts with null game_id' do
      create(:collection_artifact, user: user, game_id: nil)

      get "/api/v1/users/#{user.id}/collection/game_ids", headers: headers

      json = response.parsed_body
      expect(json['artifacts']).to contain_exactly('44444')
    end

    it 'returns both game_ids when user owns two copies of the same weapon' do
      create(:collection_weapon, user: user, weapon: weapon1, game_id: '55555')

      get "/api/v1/users/#{user.id}/collection/game_ids", headers: headers

      json = response.parsed_body
      expect(json['weapons']).to contain_exactly('11111', '22222', '55555')
    end

    it 'returns distinct granblue_ids for characters' do
      # Add the same character again (if model allows)
      create(:collection_character, user: user, character: character1)

      get "/api/v1/users/#{user.id}/collection/game_ids", headers: headers

      json = response.parsed_body
      expect(json['characters']).to contain_exactly('3040000100')
    end

    it 'does not leak other users game_ids' do
      create(:collection_weapon, user: other_user, weapon: weapon1, game_id: '99999')
      create(:collection_summon, user: other_user, game_id: '88888')
      create(:collection_artifact, user: other_user, game_id: '77777')
      create(:collection_character, user: other_user, character: character2)

      get "/api/v1/users/#{user.id}/collection/game_ids", headers: headers

      json = response.parsed_body
      expect(json['weapons']).not_to include('99999')
      expect(json['summons']).not_to include('88888')
      expect(json['artifacts']).not_to include('77777')
      expect(json['characters']).not_to include('3040000200')
    end

    it 'returns empty arrays for empty collection' do
      empty_user = create(:user, collection_privacy: :everyone)

      get "/api/v1/users/#{empty_user.id}/collection/game_ids", headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['weapons']).to eq([])
      expect(json['summons']).to eq([])
      expect(json['artifacts']).to eq([])
      expect(json['characters']).to eq([])
    end

    it 'allows owner to view their own private collection' do
      owner_token = Doorkeeper::AccessToken.create!(
        resource_owner_id: private_user.id,
        expires_in: 30.days,
        scopes: 'public'
      )
      owner_headers = {
        'Authorization' => "Bearer #{owner_token.token}",
        'Content-Type' => 'application/json'
      }

      create(:collection_weapon, user: private_user, game_id: '66666')

      get "/api/v1/users/#{private_user.id}/collection/game_ids", headers: owner_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['weapons']).to contain_exactly('66666')
    end

    it 'returns forbidden for private collection viewed by another user' do
      get "/api/v1/users/#{private_user.id}/collection/game_ids", headers: headers

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns not found for non-existent user' do
      get "/api/v1/users/#{SecureRandom.uuid}/collection/game_ids", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
