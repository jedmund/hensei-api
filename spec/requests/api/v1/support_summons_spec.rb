require 'rails_helper'

RSpec.describe 'Support Summons API', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:other_access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: other_user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end
  let(:other_headers) do
    { 'Authorization' => "Bearer #{other_access_token.token}", 'Content-Type' => 'application/json' }
  end

  let(:collection_summon) { create(:collection_summon, user: user) }

  describe 'GET /api/v1/users/:user_id/support_summons' do
    let!(:fire0) { create(:support_summon, user: user, section: :fire, position: 0) }
    let!(:misc2) { create(:support_summon, user: user, section: :misc, position: 2) }

    it 'returns the user\'s support summons ordered by section then position when public' do
      get "/api/v1/users/#{user.id}/support_summons"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      ids = json['support_summons'].map { |s| s['id'] }
      expect(ids).to eq([fire0.id, misc2.id])
    end

    it 'serializes section as a string and position as an integer' do
      get "/api/v1/users/#{user.id}/support_summons"
      json = response.parsed_body
      first = json['support_summons'].first
      expect(first['section']).to eq('fire')
      expect(first['position']).to eq(0)
      expect(first['collection_summon']).to be_present
    end

    it 'returns 403 to other users when support_summons_public is false' do
      user.update!(support_summons_public: false)

      get "/api/v1/users/#{user.id}/support_summons", headers: other_headers
      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 403 to unauthenticated callers when support_summons_public is false' do
      user.update!(support_summons_public: false)

      get "/api/v1/users/#{user.id}/support_summons"
      expect(response).to have_http_status(:forbidden)
    end

    it 'lets the owner view their own support summons even when private' do
      user.update!(support_summons_public: false)

      get "/api/v1/users/#{user.id}/support_summons", headers: headers
      expect(response).to have_http_status(:ok)
    end

    it 'returns 404 for an unknown user' do
      get "/api/v1/users/#{SecureRandom.uuid}/support_summons"
      expect(response).to have_http_status(:not_found)
    end

    it 'accepts a username in addition to a UUID' do
      get "/api/v1/users/#{user.username}/support_summons"
      expect(response).to have_http_status(:ok)
      ids = response.parsed_body['support_summons'].map { |s| s['id'] }
      expect(ids).to eq([fire0.id, misc2.id])
    end

    it 'matches usernames case-insensitively' do
      get "/api/v1/users/#{user.username.upcase}/support_summons"
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /api/v1/support_summons' do
    it 'creates a support summon for the current user' do
      cs = create(:collection_summon, user: user)

      expect {
        post '/api/v1/support_summons',
             params: { support_summon: { collection_summon_id: cs.id, section: 'water', position: 1 } }.to_json,
             headers: headers
      }.to change(SupportSummon, :count).by(1)

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json['section']).to eq('water')
      expect(json['position']).to eq(1)
    end

    it 'requires authentication' do
      cs = create(:collection_summon, user: user)
      post '/api/v1/support_summons',
           params: { support_summon: { collection_summon_id: cs.id, section: 'water', position: 0 } }.to_json,
           headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects a collection_summon owned by a different user' do
      foreign_cs = create(:collection_summon, user: other_user)

      post '/api/v1/support_summons',
           params: { support_summon: { collection_summon_id: foreign_cs.id, section: 'fire', position: 0 } }.to_json,
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects an out-of-range position' do
      cs = create(:collection_summon, user: user)
      post '/api/v1/support_summons',
           params: { support_summon: { collection_summon_id: cs.id, section: 'fire', position: 3 } }.to_json,
           headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /api/v1/support_summons/:id' do
    let!(:row) { create(:support_summon, user: user, section: :fire, position: 0) }

    it 'updates the slot' do
      patch "/api/v1/support_summons/#{row.id}",
            params: { support_summon: { position: 2 } }.to_json,
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(row.reload.position).to eq(2)
    end

    it 'returns not found when targeting another user\'s row' do
      foreign = create(:support_summon, user: other_user, section: :fire, position: 0)
      patch "/api/v1/support_summons/#{foreign.id}",
            params: { support_summon: { position: 2 } }.to_json,
            headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /api/v1/support_summons/:id' do
    let!(:row) { create(:support_summon, user: user) }

    it 'deletes the slot' do
      expect {
        delete "/api/v1/support_summons/#{row.id}", headers: headers
      }.to change(SupportSummon, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'POST /api/v1/support_summons/import' do
    let!(:fire_summon) { create(:summon, element: 2) }
    let!(:water_summon) { create(:summon, element: 3) }

    it 'imports the parsed extension payload and atomically replaces existing slots' do
      existing_cs = create(:collection_summon, user: user, summon: water_summon)
      stale = create(:support_summon, user: user, collection_summon: existing_cs, section: :water, position: 2)

      payload = {
        support_summons: [
          { gbf_section: 1, position: 0, granblue_id: fire_summon.granblue_id, level: 250 },
          { gbf_section: 0, position: 3, granblue_id: water_summon.granblue_id, level: 100 }
        ]
      }

      post '/api/v1/support_summons/import', params: payload.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(SupportSummon.find_by(id: stale.id)).to be_nil
      sections = user.support_summons.ordered.pluck(:section)
      expect(sections).to eq(%w[fire misc])
    end

    it 'auto-creates a CollectionSummon when the user does not yet own the imported summon' do
      expect(user.collection_summons.where(summon: fire_summon)).to be_empty

      post '/api/v1/support_summons/import',
           params: { support_summons: [
             { gbf_section: 1, position: 0, granblue_id: fire_summon.granblue_id, level: 100 }
           ] }.to_json,
           headers: headers

      expect(response).to have_http_status(:ok)
      cs = user.collection_summons.find_by(summon: fire_summon)
      expect(cs.uncap_level).to eq(3)
    end

    it 'returns 422 with row errors when the payload contains a bad section' do
      post '/api/v1/support_summons/import',
           params: { support_summons: [
             { gbf_section: 99, position: 0, granblue_id: fire_summon.granblue_id, level: 100 }
           ] }.to_json,
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['errors'].first['error']).to include('Unknown GBF section')
    end

    it 'requires authentication' do
      post '/api/v1/support_summons/import',
           params: { support_summons: [] }.to_json,
           headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
