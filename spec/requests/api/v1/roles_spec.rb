# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Roles API', type: :request do
  let(:user) { create(:user) }
  let(:editor) { create(:user, role: 7) }
  let(:editor_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: editor.id, expires_in: 30.days, scopes: 'public')
  end
  let(:user_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:editor_headers) { { 'Authorization' => "Bearer #{editor_token.token}" } }
  let(:user_headers) { { 'Authorization' => "Bearer #{user_token.token}" } }

  describe 'GET /api/v1/roles' do
    before do
      create(:role, name_en: 'Attacker', slot_type: 'Character', sort_order: 1)
      create(:role, :weapon, sort_order: 2)
      create(:role, :summon, sort_order: 3)
    end

    it 'returns all roles without auth' do
      get '/api/v1/roles'
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.length).to eq(3)
    end

    it 'filters by slot_type' do
      get '/api/v1/roles', params: { slot_type: 'Character' }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.length).to eq(1)
      expect(body.first['slot_type']).to eq('Character')
    end
  end

  describe 'GET /api/v1/roles/:id' do
    let!(:role) { create(:role) }

    it 'returns the role without auth' do
      get "/api/v1/roles/#{role.id}"
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['id']).to eq(role.id)
    end

    it 'returns 404 for unknown id' do
      get '/api/v1/roles/00000000-0000-0000-0000-000000000000'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/roles' do
    let(:valid_params) do
      { role: { name_en: 'Defender', name_jp: 'ディフェンダー', slot_type: 'Character' } }
    end

    context 'as editor' do
      it 'creates a role and assigns next sort_order in slot' do
        create(:role, slot_type: 'Character', sort_order: 5)

        expect {
          post '/api/v1/roles', params: valid_params, headers: editor_headers
        }.to change(Role, :count).by(1)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['name_en']).to eq('Defender')
        expect(body['sort_order']).to eq(6)
      end

      it 'rejects invalid slot_type' do
        post '/api/v1/roles',
             params: { role: { name_en: 'Bad', slot_type: 'Vehicle' } },
             headers: editor_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'as regular user' do
      it 'returns unauthorized' do
        post '/api/v1/roles', params: valid_params, headers: user_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'unauthenticated' do
      it 'returns unauthorized' do
        post '/api/v1/roles', params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/roles/:id' do
    let!(:role) { create(:role, name_en: 'Old') }

    it 'updates as editor' do
      put "/api/v1/roles/#{role.id}",
          params: { role: { name_en: 'New' } },
          headers: editor_headers
      expect(response).to have_http_status(:ok)
      expect(role.reload.name_en).to eq('New')
    end

    it 'returns unauthorized for regular user' do
      put "/api/v1/roles/#{role.id}",
          params: { role: { name_en: 'Hacked' } },
          headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE /api/v1/roles/:id' do
    let!(:role) { create(:role) }

    it 'destroys as editor' do
      expect {
        delete "/api/v1/roles/#{role.id}", headers: editor_headers
      }.to change(Role, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it 'returns 422 when the role is in use' do
      party = create(:party)
      create(:grid_character, party: party, role: role)

      expect {
        delete "/api/v1/roles/#{role.id}", headers: editor_headers
      }.not_to change(Role, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/in use/i)
    end

    it 'returns unauthorized for regular user' do
      delete "/api/v1/roles/#{role.id}", headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/roles/reorder' do
    let!(:role1) { create(:role, name_en: 'A', sort_order: 1) }
    let!(:role2) { create(:role, name_en: 'B', sort_order: 2) }

    it 'reorders as editor' do
      post '/api/v1/roles/reorder',
           params: { roles: [{ id: role1.id, sort_order: 2 }, { id: role2.id, sort_order: 1 }] },
           headers: editor_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(role1.reload.sort_order).to eq(2)
      expect(role2.reload.sort_order).to eq(1)
    end

    it 'returns 422 when roles array missing' do
      post '/api/v1/roles/reorder', params: {}, headers: editor_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns unauthorized for regular user' do
      post '/api/v1/roles/reorder',
           params: { roles: [{ id: role1.id, sort_order: 9 }] },
           headers: user_headers, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/roles/:id/upload_icon' do
    let!(:role) { create(:role) }
    # 1x1 transparent PNG
    let(:tiny_png_b64) do
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkAAIAAAoAAv/lxKUAAAAASUVORK5CYII='
    end

    before do
      stub_aws = instance_double(
        AwsService,
        s3_client: instance_double(Aws::S3::Client, put_object: true),
        bucket: 'test-bucket'
      )
      allow(AwsService).to receive(:new).and_return(stub_aws)
    end

    it 'uploads as editor and persists icon_key' do
      post "/api/v1/roles/#{role.id}/upload_icon",
           params: { image: tiny_png_b64, filename: 'icon.png' },
           headers: editor_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(role.reload.icon_key).to eq("images/roles/#{role.id}.png")
    end

    it 'renders icon_key with a cache-busting version query' do
      post "/api/v1/roles/#{role.id}/upload_icon",
           params: { image: tiny_png_b64, filename: 'icon.png' },
           headers: editor_headers, as: :json

      body = JSON.parse(response.body)
      expect(body['icon_key']).to match(%r{\Aimages/roles/#{role.id}\.png\?v=\d+\z})
    end

    it 'rejects non-PNG payload' do
      post "/api/v1/roles/#{role.id}/upload_icon",
           params: { image: Base64.strict_encode64('hello world'), filename: 'icon.png' },
           headers: editor_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns unauthorized for regular user' do
      post "/api/v1/roles/#{role.id}/upload_icon",
           params: { image: tiny_png_b64 },
           headers: user_headers, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
