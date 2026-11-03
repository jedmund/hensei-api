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

    it 'leaves deletable and the given count out of the public catalogue' do
      get '/api/v1/stickers'
      expect(json_response['stickers']).to all(satisfy { |s| !s.key?('deletable') && !s.key?('given_count') })
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
      expect(response).to have_http_status(:unprocessable_content)
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

    it 'refuses to change the slug' do
      put "/api/v1/stickers/#{sticker.id}", params: { sticker: { slug: 'renamed', meaning_en: 'New' } },
                                            headers: editor_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(sticker.reload).to have_attributes(slug: sticker.slug)
      expect(sticker.meaning_en).not_to eq('New')
    end

    it 'accepts the unchanged slug, as the editor sends it' do
      put "/api/v1/stickers/#{sticker.id}", params: { sticker: { slug: sticker.slug, meaning_en: 'New' } },
                                            headers: editor_headers
      expect(response).to have_http_status(:ok)
      expect(sticker.reload.meaning_en).to eq('New')
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
      expect(response).to have_http_status(:unprocessable_content)
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
      expect(response).to have_http_status(:unprocessable_content)
      expect(IconStorage).not_to have_received(:put)
    end

    it 'rejects a missing image' do
      post "/api/v1/stickers/#{sticker.id}/upload_image", headers: editor_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects a body over the size limit before reading it' do
      post "/api/v1/stickers/#{sticker.id}/upload_image",
           params: 'x' * (Api::V1::StickersController::UPLOAD_REQUEST_MAX_BYTES + 1),
           headers: editor_headers.merge('Content-Type' => 'application/json')
      expect(response).to have_http_status(:content_too_large)
      expect(IconStorage).not_to have_received(:put)
    end

    it 'returns 401 for non-editors' do
      post "/api/v1/stickers/#{sticker.id}/upload_image", params: { image: png_upload }, headers: member_headers
      expect(response).to have_http_status(:unauthorized)
      expect(IconStorage).not_to have_received(:put)
    end
  end

  describe 'DELETE /api/v1/stickers/:id/image' do
    before { allow(IconStorage).to receive(:delete) }

    it 'removes the Japanese image and its file' do
      sticker = create(:sticker, slug: 'cleared', image_key_jp: 'icons/stickers/cleared.ja.png')
      delete "/api/v1/stickers/#{sticker.id}/image", params: { language: 'ja' }, headers: editor_headers

      expect(response).to have_http_status(:ok)
      expect(sticker.reload.image_key_jp).to be_nil
      expect(json_response['image_url_ja']).to be_nil
      expect(IconStorage).to have_received(:delete).with('icons/stickers/cleared.ja.png')
    end

    it 'keeps a shared library image’s file' do
      entry = StickerLibrary.all.find(&:image_key_jp)
      sticker = create(:sticker, image_key: entry.image_key, image_key_jp: entry.image_key_jp)
      delete "/api/v1/stickers/#{sticker.id}/image", params: { language: 'ja' }, headers: editor_headers

      expect(sticker.reload.image_key_jp).to be_nil
      expect(IconStorage).not_to have_received(:delete)
    end

    it 'does not remove the English image' do
      sticker = create(:sticker, image_key: 'icons/stickers/x.png')
      delete "/api/v1/stickers/#{sticker.id}/image", params: { language: 'en' }, headers: editor_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(sticker.reload.image_key).to eq('icons/stickers/x.png')
    end

    it 'is for editors only' do
      sticker = create(:sticker, image_key_jp: 'icons/stickers/x.ja.png')
      delete "/api/v1/stickers/#{sticker.id}/image", params: { language: 'ja' }, headers: member_headers

      expect(response).to have_http_status(:unauthorized)
      expect(sticker.reload.image_key_jp).to eq('icons/stickers/x.ja.png')
    end
  end

  describe 'the sticker library' do
    let(:first) { StickerLibrary.all.first }
    let(:last) { StickerLibrary.all.last }

    it 'lists the library for editors, marking stickers already made from it' do
      made = create(:sticker, image_key: first.image_key)
      get '/api/v1/stickers/library', headers: editor_headers

      expect(response).to have_http_status(:ok)
      library = json_response['library']
      expect(library.size).to eq(StickerLibrary.all.size)
      expect(library.first).to include('id' => first.id, 'label' => first.label, 'image_url' => first.image_key,
                                       'image_url_ja' => first.image_key_jp, 'sticker_id' => made.id)
      expect(library.last['sticker_id']).to be_nil
    end

    it 'is for editors only' do
      get '/api/v1/stickers/library', headers: member_headers
      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates a sticker with a library sticker’s images' do
      post '/api/v1/stickers', params: { sticker: { slug: 'from-library', meaning_en: 'Hi', library_id: first.id } },
                               headers: editor_headers

      expect(response).to have_http_status(:created)
      sticker = Sticker.find_by!(slug: 'from-library')
      expect([sticker.image_key, sticker.image_key_jp]).to eq([first.image_key, first.image_key_jp])
    end

    it 'swaps a sticker’s images for a library sticker’s' do
      sticker = create(:sticker, image_key: 'icons/stickers/mine.png')
      put "/api/v1/stickers/#{sticker.id}", params: { sticker: { library_id: last.id } }, headers: editor_headers

      expect(response).to have_http_status(:ok)
      expect(sticker.reload.image_key).to eq(last.image_key)
    end

    it 'rejects an unknown library sticker' do
      post '/api/v1/stickers', params: { sticker: { slug: 'nope', meaning_en: 'Hi', library_id: 999_999 } },
                               headers: editor_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(Sticker.exists?(slug: 'nope')).to be(false)
    end

    it 'keeps the shared library image when one is uploaded over it' do
      allow(IconStorage).to receive(:put)
      allow(IconStorage).to receive(:delete)
      sticker = create(:sticker, slug: 'shared', image_key: first.image_key)

      post "/api/v1/stickers/#{sticker.id}/upload_image", params: { image: png_upload }, headers: editor_headers

      expect(sticker.reload.image_key).to eq('icons/stickers/shared.png')
      expect(IconStorage).not_to have_received(:delete)
    end

    it 'still removes the sticker’s own image when it’s replaced in another format' do
      allow(IconStorage).to receive(:put)
      allow(IconStorage).to receive(:delete)
      sticker = create(:sticker, slug: 'own', image_key: 'icons/stickers/own.webp')

      post "/api/v1/stickers/#{sticker.id}/upload_image", params: { image: png_upload }, headers: editor_headers

      expect(IconStorage).to have_received(:delete).with('icons/stickers/own.webp')
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
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 401 for non-editors and leaves the order alone' do
      put '/api/v1/stickers/reorder', params: { ids: [b.id, a.id] }, headers: member_headers
      expect(response).to have_http_status(:unauthorized)
      expect([a.reload.position, b.reload.position]).to eq([0, 1])
    end

    it 'returns 401 when signed out' do
      put '/api/v1/stickers/reorder', params: { ids: [b.id, a.id] }
      expect(response).to have_http_status(:unauthorized)
      expect(a.reload.position).to eq(0)
    end
  end

  describe 'GET /api/v1/stickers/:id' do
    let!(:sticker) { create(:sticker, :inactive, slug: 'retired', image_key: 'icons/stickers/stamp3.png') }

    it 'finds a sticker by slug or id for editors, in the editor view' do
      get '/api/v1/stickers/retired', headers: editor_headers
      expect(response).to have_http_status(:ok)
      expect(json_response).to include('id' => sticker.id, 'slug' => 'retired', 'active' => false, 'deletable' => true)
      expect(json_response['image_url']).to start_with('icons/stickers/stamp3.png?v=')

      get "/api/v1/stickers/#{sticker.id}", headers: editor_headers
      expect(json_response['slug']).to eq('retired')
    end

    it 'says how often a sticker was given, and that a given one cannot be deleted' do
      get '/api/v1/stickers/retired', headers: editor_headers
      expect(json_response).to include('given_count' => 0, 'deletable' => true)

      create_list(:party_sticker, 2, sticker: sticker)
      get '/api/v1/stickers/retired', headers: editor_headers
      expect(json_response).to include('given_count' => 2, 'deletable' => false)
    end

    it 'returns 404 for an unknown sticker' do
      get '/api/v1/stickers/nope', headers: editor_headers
      expect(response).to have_http_status(:not_found)
    end

    it 'is for editors only' do
      get '/api/v1/stickers/retired', headers: member_headers
      expect(response).to have_http_status(:unauthorized)
      get '/api/v1/stickers/retired'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'validation on write' do
    let!(:sticker) { create(:sticker) }

    it 'rejects a missing active flag' do
      put "/api/v1/stickers/#{sticker.id}", params: { sticker: { active: '' } }, headers: editor_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(sticker.reload.active).to be(true)
    end

    it 'ignores image keys sent as params' do
      put "/api/v1/stickers/#{sticker.id}", params: { sticker: { image_key: 'weapons/x.png' } }, headers: editor_headers
      expect(response).to have_http_status(:ok)
      expect(sticker.reload.image_key).to be_nil
    end
  end
end
