# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Stickers', type: :request do
  let(:editor) { create(:user, role: 7) }
  let(:member) { create(:user, role: 1) }
  let(:editor_headers) { bearer_headers(editor) }
  let(:member_headers) { bearer_headers(member) }

  def json_response
    JSON.parse(response.body)
  end

  describe 'GET /api/v1/stickers' do
    let!(:second) { create(:sticker, slug: 'second', position: 2) }
    let!(:first) { create(:sticker, slug: 'first', position: 1, meaning_en: 'Fast', meaning_jp: '速い') }
    let!(:retired) { create(:sticker, :inactive, slug: 'retired', position: 0) }

    it 'returns active stickers in position order, publicly' do
      get '/api/v1/stickers'

      expect(response).to have_http_status(:ok)
      expect(json_response['stickers'].map { |s| s['slug'] }).to eq(%w[first second])
      expect(json_response['stickers'].first).to include(
        'id' => first.id, 'meaning' => { 'en' => 'Fast', 'ja' => '速い' },
        'image_url' => nil, 'position' => 1, 'active' => true
      )
    end

    it 'lets editors include inactive stickers' do
      get '/api/v1/stickers', params: { include_inactive: true }, headers: editor_headers
      expect(json_response['stickers'].map { |s| s['slug'] }).to eq(%w[retired first second])
    end

    it 'tells editors which stickers can still be deleted' do
      given = create(:sticker, slug: 'given')
      create(:party_sticker, sticker: given)
      get '/api/v1/stickers', params: { include_inactive: true }, headers: editor_headers
      deletable = json_response['stickers'].to_h { |s| [s['slug'], s['deletable']] }
      expect(deletable['given']).to be(false)
      expect(deletable.except('given').values).to all(be(true))
    end

    it 'leaves deletable out of the public catalogue' do
      get '/api/v1/stickers'
      expect(json_response['stickers']).to all(satisfy { |s| !s.key?('deletable') })
    end

    it 'ignores include_inactive for non-editors' do
      get '/api/v1/stickers', params: { include_inactive: true }, headers: member_headers
      expect(json_response['stickers'].map { |s| s['slug'] }).to eq(%w[first second])
    end

    it 'busts the cached catalogue when a sticker changes' do
      expect(Rails.cache).to receive(:delete).with(Sticker::CATALOGUE_CACHE_KEY).at_least(:once)
      first.update!(meaning_en: 'Faster')
    end
  end

  describe 'POST /api/v1/stickers' do
    let(:params) { { sticker: { slug: 'full-auto', meaning_en: 'Full-auto friendly', meaning_jp: 'フルオート向け', position: 3 } } }

    it 'creates a sticker as an editor' do
      post '/api/v1/stickers', params: params, headers: editor_headers
      expect(response).to have_http_status(:created)
      expect(json_response).to include('slug' => 'full-auto', 'active' => true, 'position' => 3)
    end

    it 'rejects an invalid slug' do
      post '/api/v1/stickers', params: { sticker: { slug: '../Bad Slug', meaning_en: 'x' } }, headers: editor_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 401 for non-editors' do
      post '/api/v1/stickers', params: params, headers: member_headers
      expect(response).to have_http_status(:unauthorized)
      expect(Sticker.count).to eq(0)
    end

    it 'returns 401 when signed out' do
      post '/api/v1/stickers', params: params
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /api/v1/stickers/:id' do
    let!(:sticker) { create(:sticker) }

    it 'updates and deactivates as an editor' do
      put "/api/v1/stickers/#{sticker.id}", params: { sticker: { meaning_en: 'New', active: false } }, headers: editor_headers
      expect(response).to have_http_status(:ok)
      expect(sticker.reload).to have_attributes(meaning_en: 'New', active: false)
    end

    it 'returns 401 for non-editors' do
      put "/api/v1/stickers/#{sticker.id}", params: { sticker: { meaning_en: 'New' } }, headers: member_headers
      expect(response).to have_http_status(:unauthorized)
      expect(sticker.reload.meaning_en).not_to eq('New')
    end
  end

  describe 'DELETE /api/v1/stickers/:id' do
    let!(:sticker) { create(:sticker) }

    it 'deletes a sticker nobody has given' do
      delete "/api/v1/stickers/#{sticker.id}", headers: editor_headers
      expect(response).to have_http_status(:no_content)
      expect(Sticker.exists?(sticker.id)).to be(false)
    end

    it 'returns 422 once the sticker has been given' do
      create(:party_sticker, sticker: sticker)
      delete "/api/v1/stickers/#{sticker.id}", headers: editor_headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['error']).to be_present
      expect(Sticker.exists?(sticker.id)).to be(true)
    end

    it 'returns 401 for non-editors' do
      delete "/api/v1/stickers/#{sticker.id}", headers: member_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/stickers/:id/upload_image' do
    let!(:sticker) { create(:sticker, slug: 'cleared') }

    before do
      allow(IconStorage).to receive(:put)
      allow(IconStorage).to receive(:delete)
    end

    it 'stores a multipart PNG under icons/stickers/<slug>.png' do
      post "/api/v1/stickers/#{sticker.id}/upload_image", params: { image: png_upload }, headers: editor_headers

      expect(response).to have_http_status(:ok)
      expect(IconStorage).to have_received(:put).with('icons/stickers/cleared.png', kind_of(String), content_type: 'image/png')
      expect(sticker.reload.image_key).to eq('icons/stickers/cleared.png')
      expect(json_response['image_url']).to start_with('icons/stickers/cleared.png?v=')
    end

    it 'bumps the image version when the same key is uploaded again' do
      sticker.update!(image_key: 'icons/stickers/cleared.png', updated_at: 1.day.ago)
      expect do
        post "/api/v1/stickers/#{sticker.id}/upload_image", params: { image: png_upload }, headers: editor_headers
      end.to(change { sticker.reload.updated_at })
      expect(json_response['image_url']).to eq("icons/stickers/cleared.png?v=#{sticker.updated_at.to_i}")
    end

    it 'stores the Japanese image apart, under icons/stickers/<slug>.ja.png' do
      sticker.update!(image_key: 'icons/stickers/cleared.png')
      post "/api/v1/stickers/#{sticker.id}/upload_image", params: { image: png_upload, language: 'ja' },
                                                          headers: editor_headers

      expect(response).to have_http_status(:ok)
      expect(IconStorage).to have_received(:put).with('icons/stickers/cleared.ja.png', kind_of(String),
                                                      content_type: 'image/png')
      expect(sticker.reload.image_key_jp).to eq('icons/stickers/cleared.ja.png')
      expect(sticker.image_key).to eq('icons/stickers/cleared.png')
      expect(json_response['image_url_ja']).to start_with('icons/stickers/cleared.ja.png?v=')
      expect(IconStorage).not_to have_received(:delete)
    end

    it 'has no Japanese image until one is uploaded' do
      post "/api/v1/stickers/#{sticker.id}/upload_image", params: { image: png_upload }, headers: editor_headers
      expect(json_response['image_url_ja']).to be_nil
    end

    it 'accepts a base64 string' do
      post "/api/v1/stickers/#{sticker.id}/upload_image", params: { image: CommunitySpecHelpers::PNG_BASE64 },
                                                          headers: editor_headers
      expect(response).to have_http_status(:ok)
    end

    it 'rejects a JPEG' do
      upload = Rack::Test::UploadedFile.new(StringIO.new(jpeg_bytes), 'image/jpeg', original_filename: 'x.jpg')
      post "/api/v1/stickers/#{sticker.id}/upload_image", params: { image: upload }, headers: editor_headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(IconStorage).not_to have_received(:put)
    end

    it 'rejects a missing image' do
      post "/api/v1/stickers/#{sticker.id}/upload_image", headers: editor_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 401 for non-editors' do
      post "/api/v1/stickers/#{sticker.id}/upload_image", params: { image: png_upload }, headers: member_headers
      expect(response).to have_http_status(:unauthorized)
      expect(IconStorage).not_to have_received(:put)
    end
  end

  describe 'PUT /api/v1/stickers/reorder' do
    let!(:a) { create(:sticker, position: 0) }
    let!(:b) { create(:sticker, position: 1) }

    it 'sets positions in the given order' do
      put '/api/v1/stickers/reorder', params: { ids: [b.id, a.id] }, headers: editor_headers
      expect(response).to have_http_status(:ok)
      expect(json_response['stickers'].map { |s| s['id'] }).to eq([b.id, a.id])
      expect(b.reload.position).to eq(0)
    end

    it 'returns 422 for unknown ids' do
      put '/api/v1/stickers/reorder', params: { ids: [a.id, 'nope'] }, headers: editor_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 401 for non-editors' do
      put '/api/v1/stickers/reorder', params: { ids: [b.id, a.id] }, headers: member_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
