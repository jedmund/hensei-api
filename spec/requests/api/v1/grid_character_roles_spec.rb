# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GridCharacterRoles API', type: :request do
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

  describe 'GET /api/v1/grid_character_roles' do
    before do
      create(:grid_character_role, name_en: 'Attacker', sort_order: 1)
      create(:grid_character_role, name_en: 'Defender', sort_order: 2)
      create(:grid_character_role, name_en: 'Healer',   sort_order: 3)
    end

    it 'returns all roles without auth' do
      get '/api/v1/grid_character_roles'
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.length).to eq(3)
    end
  end

  describe 'GET /api/v1/grid_character_roles/:id' do
    let!(:role) { create(:grid_character_role) }

    it 'returns the role without auth' do
      get "/api/v1/grid_character_roles/#{role.id}"
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['id']).to eq(role.id)
    end

    it 'returns 404 for unknown id' do
      get '/api/v1/grid_character_roles/00000000-0000-0000-0000-000000000000'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/grid_character_roles' do
    let(:valid_params) do
      { grid_character_role: { name_en: 'Defender', name_jp: 'ディフェンダー' } }
    end

    context 'as editor' do
      it 'creates a role and assigns next sort_order' do
        create(:grid_character_role, sort_order: 5)

        expect {
          post '/api/v1/grid_character_roles', params: valid_params, headers: editor_headers
        }.to change(GridCharacterRole, :count).by(1)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['name_en']).to eq('Defender')
        expect(body['sort_order']).to eq(6)
      end

      it 'rejects missing name_en' do
        post '/api/v1/grid_character_roles',
             params: { grid_character_role: { name_jp: 'ディフェンダー' } },
             headers: editor_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'as regular user' do
      it 'returns unauthorized' do
        post '/api/v1/grid_character_roles', params: valid_params, headers: user_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'unauthenticated' do
      it 'returns unauthorized' do
        post '/api/v1/grid_character_roles', params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /api/v1/grid_character_roles/:id' do
    let!(:role) { create(:grid_character_role, name_en: 'Old') }

    it 'updates as editor' do
      put "/api/v1/grid_character_roles/#{role.id}",
          params: { grid_character_role: { name_en: 'New' } },
          headers: editor_headers
      expect(response).to have_http_status(:ok)
      expect(role.reload.name_en).to eq('New')
    end

    it 'returns unauthorized for regular user' do
      put "/api/v1/grid_character_roles/#{role.id}",
          params: { grid_character_role: { name_en: 'Hacked' } },
          headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE /api/v1/grid_character_roles/:id' do
    let!(:role) { create(:grid_character_role) }

    it 'destroys as editor' do
      expect {
        delete "/api/v1/grid_character_roles/#{role.id}", headers: editor_headers
      }.to change(GridCharacterRole, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it 'destroys role assignments along with the role' do
      party = create(:party)
      gc = create(:grid_character, party: party)
      gc.grid_character_roles << role

      expect {
        delete "/api/v1/grid_character_roles/#{role.id}", headers: editor_headers
      }.to change(GridCharacterRole, :count).by(-1)
                                            .and change(GridCharacterRoleAssignment, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'returns unauthorized for regular user' do
      delete "/api/v1/grid_character_roles/#{role.id}", headers: user_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/grid_character_roles/reorder' do
    let!(:role1) { create(:grid_character_role, name_en: 'A', sort_order: 1) }
    let!(:role2) { create(:grid_character_role, name_en: 'B', sort_order: 2) }

    it 'reorders as editor' do
      post '/api/v1/grid_character_roles/reorder',
           params: { roles: [{ id: role1.id, sort_order: 2 }, { id: role2.id, sort_order: 1 }] },
           headers: editor_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(role1.reload.sort_order).to eq(2)
      expect(role2.reload.sort_order).to eq(1)
    end

    it 'returns 422 when roles array missing' do
      post '/api/v1/grid_character_roles/reorder', params: {}, headers: editor_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 with the missing ids and rolls back when a role id is unknown' do
      bogus = SecureRandom.uuid
      original_sort_orders = [role1.sort_order, role2.sort_order]

      post '/api/v1/grid_character_roles/reorder',
           params: { roles: [{ id: role1.id, sort_order: 9 }, { id: bogus, sort_order: 1 }] },
           headers: editor_headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body['ids']).to include(bogus)

      # The valid update is rejected up front, not partially applied.
      expect([role1.reload.sort_order, role2.reload.sort_order]).to eq(original_sort_orders)
    end

    it 'returns unauthorized for regular user' do
      post '/api/v1/grid_character_roles/reorder',
           params: { roles: [{ id: role1.id, sort_order: 9 }] },
           headers: user_headers, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/grid_character_roles/:id/upload_icon' do
    let!(:role) { create(:grid_character_role) }
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
      post "/api/v1/grid_character_roles/#{role.id}/upload_icon",
           params: { image: tiny_png_b64, filename: 'icon.png' },
           headers: editor_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(role.reload.icon_key).to eq("images/grid_character_roles/#{role.id}.png")
    end

    it 'renders icon_key with a cache-busting version query' do
      post "/api/v1/grid_character_roles/#{role.id}/upload_icon",
           params: { image: tiny_png_b64, filename: 'icon.png' },
           headers: editor_headers, as: :json

      body = JSON.parse(response.body)
      expect(body['icon_key']).to match(%r{\Aimages/grid_character_roles/#{role.id}\.png\?v=\d+\z})
    end

    it 'rejects non-PNG payload' do
      post "/api/v1/grid_character_roles/#{role.id}/upload_icon",
           params: { image: Base64.strict_encode64('hello world'), filename: 'icon.png' },
           headers: editor_headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects an oversized icon (>128x128)' do
      oversize_png = Tempfile.create(['oversize', '.png']) do |tmp|
        tmp.binmode
        MiniMagick::Tool::Magick.new do |c|
          c.size '200x200'
          c << 'xc:transparent'
          c << tmp.path
        end
        File.binread(tmp.path)
      end

      post "/api/v1/grid_character_roles/#{role.id}/upload_icon",
           params: { image: Base64.strict_encode64(oversize_png), filename: 'icon.png' },
           headers: editor_headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['error']).to match(/128x128 or smaller/)
    end

    it 'returns unauthorized for regular user' do
      post "/api/v1/grid_character_roles/#{role.id}/upload_icon",
           params: { image: tiny_png_b64 },
           headers: user_headers, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
