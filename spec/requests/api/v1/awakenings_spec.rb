# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Awakenings', type: :request do
  include CommunitySpecHelpers

  let(:editor) { create(:user, role: 7) }
  let(:member) { create(:user, role: 1) }
  let(:editor_headers) { bearer_headers(editor) }
  let(:member_headers) { bearer_headers(member) }

  def png_of(size)
    Tempfile.create(['awakening', '.png']) do |tmp|
      MiniMagick::Tool::Convert.new do |c|
        c.size size
        c << 'xc:transparent'
        c << tmp.path
      end
      File.binread(tmp.path)
    end
  end

  def jpeg_of(size)
    Tempfile.create(['awakening', '.jpg']) do |tmp|
      MiniMagick::Tool::Convert.new do |c|
        c.size size
        c << 'xc:white'
        c << tmp.path
      end
      File.binread(tmp.path)
    end
  end

  describe 'POST /api/v1/awakenings/:id/upload_image' do
    let!(:awakening) { create(:awakening, slug: 'weapon-atk', object_type: 'Weapon') }
    let(:url) { "/api/v1/awakenings/#{awakening.id}/upload_image" }

    before { allow(IconStorage).to receive(:put) }

    it 'stores the PNG under icons/awakening/<slug>.png and returns the awakening' do
      post url, params: { image: Base64.strict_encode64(png_of('80x80')), filename: 'atk.png' },
                headers: editor_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(IconStorage).to have_received(:put)
        .with('icons/awakening/weapon-atk.png', start_with(IconUploadValidator::PNG_SIGNATURE), content_type: 'image/png')
      expect(response.parsed_body).to include('id' => awakening.id, 'slug' => 'weapon-atk',
                                              'name' => { 'en' => awakening.name_en, 'ja' => awakening.name_jp })
    end

    it 'rejects bytes that are not a PNG' do
      post url, params: { image: Base64.strict_encode64('hello world') }, headers: editor_headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('Icon must be a PNG')
      expect(IconStorage).not_to have_received(:put)
    end

    it 'rejects a JPEG for a weapon awakening' do
      post url, params: { image: Base64.strict_encode64(jpeg_of('50x50')) }, headers: editor_headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(IconStorage).not_to have_received(:put)
    end

    context 'with a character awakening' do
      let!(:awakening) { create(:awakening, slug: 'character-multi', object_type: 'Character') }

      it 'stores the JPEG under icons/awakening/<slug>.jpg' do
        post url, params: { image: Base64.strict_encode64(jpeg_of('50x50')) }, headers: editor_headers, as: :json

        expect(response).to have_http_status(:ok)
        expect(IconStorage).to have_received(:put)
          .with('icons/awakening/character-multi.jpg', start_with(IconUploadValidator::JPEG_SIGNATURE),
                content_type: 'image/jpeg')
      end

      it 'rejects a PNG' do
        post url, params: { image: Base64.strict_encode64(png_of('50x50')) }, headers: editor_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(IconStorage).not_to have_received(:put)
      end
    end

    it 'rejects an image larger than an icon' do
      post url, params: { image: Base64.strict_encode64(png_of('200x200')) }, headers: editor_headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to match(/128x128 or smaller/)
    end

    it 'rejects a missing image' do
      post url, params: {}, headers: editor_headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(IconStorage).not_to have_received(:put)
    end

    it 'rejects a body over the size limit before reading it' do
      post url, params: 'x' * (Api::V1::AwakeningsController::UPLOAD_REQUEST_MAX_BYTES + 1),
                headers: editor_headers.merge('Content-Type' => 'application/json')

      expect(response).to have_http_status(:payload_too_large)
      expect(IconStorage).not_to have_received(:put)
    end

    it 'refuses an awakening whose slug is not path-safe' do
      awakening.update_column(:slug, '../weapon-atk')
      post url, params: { image: CommunitySpecHelpers::PNG_BASE64 }, headers: editor_headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(IconStorage).not_to have_received(:put)
    end

    it 'returns 401 for non-editors' do
      post url, params: { image: CommunitySpecHelpers::PNG_BASE64 }, headers: member_headers, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(IconStorage).not_to have_received(:put)
    end

    it 'returns 404 for an unknown awakening' do
      post "/api/v1/awakenings/#{SecureRandom.uuid}/upload_image",
           params: { image: CommunitySpecHelpers::PNG_BASE64 }, headers: editor_headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'slug validation' do
    it 'rejects a slug that is not lowercase words joined by hyphens' do
      post '/api/v1/awakenings',
           params: { awakening: { name_en: 'Bad', slug: 'weapon/atk', object_type: 'Weapon', order: 1 } },
           headers: editor_headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects a slug change to one that is not path-safe' do
      awakening = create(:awakening, slug: 'weapon-def')
      put "/api/v1/awakenings/#{awakening.id}", params: { awakening: { slug: 'Weapon Def' } },
                                                headers: editor_headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(awakening.reload.slug).to eq('weapon-def')
    end
  end
end
