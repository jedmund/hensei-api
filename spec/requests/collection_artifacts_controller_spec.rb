# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Collection Artifacts API', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end

  let(:artifact) { create(:artifact) }
  let(:quirk_artifact) { create(:artifact, :quirk) }

  before do
    # Seed required artifact skills for validation
    ArtifactSkill.find_or_create_by!(skill_group: :group_i, modifier: 1) do |s|
      s.name_en = 'ATK'
      s.name_jp = '攻撃力'
      s.base_values = [1320, 1440, 1560, 1680, 1800]
      s.growth = 300.0
      s.polarity = :positive
    end
    ArtifactSkill.find_or_create_by!(skill_group: :group_i, modifier: 2) do |s|
      s.name_en = 'HP'
      s.name_jp = 'HP'
      s.base_values = [660, 720, 780, 840, 900]
      s.growth = 150.0
      s.polarity = :positive
    end
    ArtifactSkill.find_or_create_by!(skill_group: :group_ii, modifier: 1) do |s|
      s.name_en = 'C.A. DMG'
      s.name_jp = '奥義ダメ'
      s.base_values = [13.2, 14.4, 15.6, 16.8, 18.0]
      s.growth = 3.0
      s.polarity = :positive
    end
    ArtifactSkill.find_or_create_by!(skill_group: :group_iii, modifier: 1) do |s|
      s.name_en = 'Chain Burst DMG'
      s.name_jp = 'チェインダメ'
      s.base_values = [6, 7, 8, 9, 10]
      s.growth = 2.5
      s.polarity = :positive
    end
    ArtifactSkill.clear_cache!
  end

  describe 'GET /api/v1/users/:user_id/collection/artifacts' do
    let!(:collection_artifact1) { create(:collection_artifact, user: user, artifact: artifact) }
    let!(:collection_artifact2) { create(:collection_artifact, user: user, element: :water) }
    let!(:other_user_artifact) { create(:collection_artifact, user: other_user) }

    it "returns the user's collection artifacts" do
      get "/api/v1/users/#{user.id}/collection/artifacts", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['artifacts'].length).to eq(2)
    end

    it 'supports pagination' do
      get "/api/v1/users/#{user.id}/collection/artifacts", params: { page: 1, limit: 1 }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['artifacts'].length).to eq(1)
      expect(json['meta']['total_pages']).to be >= 2
    end

    it 'filters by artifact_id' do
      get "/api/v1/users/#{user.id}/collection/artifacts", params: { artifact_id: artifact.id }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['artifacts'].length).to eq(1)
    end

    it 'filters by element' do
      get "/api/v1/users/#{user.id}/collection/artifacts", params: { element: 'water' }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['artifacts'].all? { |a| a['element'] == 'water' }).to be true
    end

    it 'returns unauthorized without authentication' do
      other_user.update!(collection_visibility: 'private')
      get "/api/v1/users/#{other_user.id}/collection/artifacts"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/users/:user_id/collection/artifacts/:id' do
    let!(:collection_artifact) { create(:collection_artifact, user: user, artifact: artifact) }

    it 'returns the collection artifact' do
      get "/api/v1/users/#{user.id}/collection/artifacts/#{collection_artifact.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(collection_artifact.id)
      expect(json['artifact']['id']).to eq(artifact.id)
    end
  end

  describe 'POST /api/v1/collection/artifacts' do
    let(:valid_attributes) do
      {
        collection_artifact: {
          artifact_id: artifact.id,
          element: 'fire',
          level: 1,
          skill1: { modifier: 1, strength: 1800, level: 1 },
          skill2: { modifier: 2, strength: 900, level: 1 },
          skill3: { modifier: 1, strength: 18.0, level: 1 },
          skill4: { modifier: 1, strength: 10, level: 1 }
        }
      }
    end

    it 'creates a new collection artifact' do
      expect do
        post '/api/v1/collection/artifacts', params: valid_attributes.to_json, headers: headers
      end.to change(CollectionArtifact, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['artifact']['id']).to eq(artifact.id)
      expect(json['element']).to eq('fire')
    end

    it 'allows multiple copies of the same artifact' do
      create(:collection_artifact, user: user, artifact: artifact)

      expect do
        post '/api/v1/collection/artifacts', params: valid_attributes.to_json, headers: headers
      end.to change(CollectionArtifact, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it 'creates artifact with nickname' do
      attributes_with_nickname = valid_attributes.deep_merge(
        collection_artifact: { nickname: 'My Best Artifact' }
      )

      post '/api/v1/collection/artifacts', params: attributes_with_nickname.to_json, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['nickname']).to eq('My Best Artifact')
    end

    it 'creates quirk artifact with proficiency' do
      quirk_attributes = {
        collection_artifact: {
          artifact_id: quirk_artifact.id,
          element: 'dark',
          proficiency: 'staff',
          level: 1,
          skill1: {},
          skill2: {},
          skill3: {},
          skill4: {}
        }
      }

      post '/api/v1/collection/artifacts', params: quirk_attributes.to_json, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['proficiency']).to eq('staff')
    end

    it 'returns error when skill1 and skill2 have same modifier' do
      invalid_attributes = valid_attributes.deep_merge(
        collection_artifact: {
          skill1: { modifier: 1, strength: 1800, level: 1 },
          skill2: { modifier: 1, strength: 1800, level: 1 }
        }
      )

      post '/api/v1/collection/artifacts', params: invalid_attributes.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors'].to_s).to include('cannot have the same modifier')
    end

    it 'returns unauthorized without authentication' do
      post '/api/v1/collection/artifacts', params: valid_attributes.to_json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /api/v1/collection/artifacts/:id' do
    let!(:collection_artifact) { create(:collection_artifact, user: user, artifact: artifact, level: 1) }

    it 'updates the collection artifact' do
      update_attributes = {
        collection_artifact: {
          nickname: 'Updated Name',
          element: 'water'
        }
      }

      put "/api/v1/collection/artifacts/#{collection_artifact.id}",
          params: update_attributes.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['nickname']).to eq('Updated Name')
      expect(json['element']).to eq('water')
    end

    it 'returns not found for other user\'s artifact' do
      other_collection = create(:collection_artifact, user: other_user)

      put "/api/v1/collection/artifacts/#{other_collection.id}",
          params: { collection_artifact: { nickname: 'Hack' } }.to_json, headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /api/v1/collection/artifacts/:id' do
    let!(:collection_artifact) { create(:collection_artifact, user: user, artifact: artifact) }

    it 'deletes the collection artifact' do
      expect do
        delete "/api/v1/collection/artifacts/#{collection_artifact.id}", headers: headers
      end.to change(CollectionArtifact, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'returns not found for other user\'s artifact' do
      other_collection = create(:collection_artifact, user: other_user)

      expect do
        delete "/api/v1/collection/artifacts/#{other_collection.id}", headers: headers
      end.not_to change(CollectionArtifact, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/collection/artifacts/batch' do
    let(:artifact2) { create(:artifact, :dagger) }

    it 'creates multiple collection artifacts' do
      batch_attributes = {
        collection_artifacts: [
          {
            artifact_id: artifact.id,
            element: 'fire',
            level: 1,
            skill1: { modifier: 1, strength: 1800, level: 1 },
            skill2: { modifier: 2, strength: 900, level: 1 },
            skill3: { modifier: 1, strength: 18.0, level: 1 },
            skill4: { modifier: 1, strength: 10, level: 1 }
          },
          {
            artifact_id: artifact2.id,
            element: 'water',
            level: 1,
            skill1: { modifier: 1, strength: 1800, level: 1 },
            skill2: { modifier: 2, strength: 900, level: 1 },
            skill3: { modifier: 1, strength: 18.0, level: 1 },
            skill4: { modifier: 1, strength: 10, level: 1 }
          }
        ]
      }

      expect do
        post '/api/v1/collection/artifacts/batch', params: batch_attributes.to_json, headers: headers
      end.to change(CollectionArtifact, :count).by(2)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['meta']['created']).to eq(2)
      expect(json['meta']['errors']).to be_empty
    end

    it 'returns multi_status when some items fail' do
      batch_attributes = {
        collection_artifacts: [
          {
            artifact_id: artifact.id,
            element: 'fire',
            level: 1,
            skill1: { modifier: 1, strength: 1800, level: 1 },
            skill2: { modifier: 2, strength: 900, level: 1 },
            skill3: { modifier: 1, strength: 18.0, level: 1 },
            skill4: { modifier: 1, strength: 10, level: 1 }
          },
          {
            artifact_id: artifact.id,
            element: 'invalid_element', # Invalid
            level: 1
          }
        ]
      }

      post '/api/v1/collection/artifacts/batch', params: batch_attributes.to_json, headers: headers

      expect(response).to have_http_status(:multi_status)
      json = JSON.parse(response.body)
      expect(json['meta']['created']).to eq(1)
      expect(json['meta']['errors'].length).to eq(1)
    end
  end
end
