# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /api/v1/awakenings/:id', type: :request do
  include CommunitySpecHelpers

  let(:editor_headers) { bearer_headers(create(:user, role: 7)) }
  let!(:awakening) { create(:awakening, :for_weapon) }

  it 'deletes an awakening no weapon lists' do
    delete "/api/v1/awakenings/#{awakening.id}", headers: editor_headers

    expect(response).to have_http_status(:no_content)
    expect(Awakening.exists?(awakening.id)).to be(false)
  end

  it 'keeps an awakening a weapon lists' do
    create(:weapon_awakening, awakening: awakening)

    delete "/api/v1/awakenings/#{awakening.id}", headers: editor_headers

    expect(response).to have_http_status(:internal_server_error)
    expect(Awakening.exists?(awakening.id)).to be(true)
  end
end
