# frozen_string_literal: true

require 'rails_helper'

# download_status sits beside the editor-only download actions and is gated
# the same way.
RSpec.describe 'download_status access', type: :request do
  def headers_for(user)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}" }
  end

  let(:editor_headers) { headers_for(create(:user, role: 7)) }
  let(:member_headers) { headers_for(create(:user, role: 1)) }

  {
    'weapons' => -> { create(:weapon).id },
    'summons' => -> { create(:summon).id },
    'characters' => -> { create(:character).id },
    'artifacts' => -> { create(:artifact).id },
    'raids' => -> { create(:raid).slug },
    'bullets' => lambda {
      Bullet.create!(name_en: 'Test Bullet', slug: "test-bullet-#{SecureRandom.hex(4)}",
                     bullet_type: Bullet::BULLET_TYPES.values.first).id
    }
  }.each do |resource, build_id|
    describe "GET /api/v1/#{resource}/:id/download_status" do
      let(:path) { "/api/v1/#{resource}/#{instance_exec(&build_id)}/download_status" }

      it 'rejects anonymous requests' do
        get path

        expect(response).to have_http_status(:unauthorized)
      end

      it 'rejects users without the editor role' do
        get path, headers: member_headers

        expect(response).to have_http_status(:unauthorized)
      end

      it 'allows editors' do
        get path, headers: editor_headers

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
