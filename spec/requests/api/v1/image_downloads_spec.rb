# frozen_string_literal: true

require 'rails_helper'

# The async download_images actions check the requested size before queueing
# a job, the same way the sync download_image actions do.
RSpec.describe 'Image download options', type: :request do
  include CommunitySpecHelpers

  let(:editor) { create(:user, role: 7) }
  let(:headers) { bearer_headers(editor) }

  shared_examples 'an async image download' do |job_class|
    before { allow(job_class).to receive(:update_status) if job_class.respond_to?(:update_status) }

    it 'queues a job for every size by default' do
      expect { post url, params: {}, headers: headers, as: :json }.to have_enqueued_job(job_class)
      expect(response).to have_http_status(:accepted).or have_http_status(:ok)
    end

    it 'queues a job for a known size' do
      expect do
        post url, params: { options: { size: valid_size } }, headers: headers, as: :json
      end.to have_enqueued_job(job_class).with(anything, hash_including(size: valid_size))
    end

    it 'refuses an unknown size without queueing a job' do
      ['../main', 'huge', ['main'], { 'a' => 'b' }].each do |size|
        expect do
          post url, params: { options: { size: size } }, headers: headers, as: :json
        end.not_to have_enqueued_job(job_class)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to start_with('Invalid size')
      end
    end
  end

  describe 'POST /weapons/:id/download_images' do
    let(:weapon) { create(:weapon) }
    let(:url) { "/api/v1/weapons/#{weapon.id}/download_images" }
    let(:valid_size) { 'grid' }

    it_behaves_like 'an async image download', DownloadWeaponImagesJob

    it 'refuses a weapon whose element variant ids are not plain weapon ids' do
      weapon.update_column(:element_variant_ids, { '1' => '../1040001000' })

      expect { post url, params: {}, headers: headers, as: :json }.not_to have_enqueued_job(DownloadWeaponImagesJob)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'still refuses an unknown size on the sync download' do
      post "/api/v1/weapons/#{weapon.id}/download_image", params: { size: 'huge' }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'POST /characters/:id/download_images' do
    let(:character) { create(:character) }
    let(:url) { "/api/v1/characters/#{character.id}/download_images" }
    let(:valid_size) { 'detail' }

    it_behaves_like 'an async image download', DownloadCharacterImagesJob
  end

  describe 'POST /summons/:id/download_images' do
    let(:summon) { create(:summon) }
    let(:url) { "/api/v1/summons/#{summon.id}/download_images" }
    let(:valid_size) { 'wide' }

    it_behaves_like 'an async image download', DownloadSummonImagesJob
  end

  describe 'POST /raids/:id/download_images' do
    let(:raid) { create(:raid) }
    let(:url) { "/api/v1/raids/#{raid.id}/download_images" }
    let(:valid_size) { 'thumbnail' }

    it_behaves_like 'an async image download', DownloadRaidImagesJob
  end

  describe 'POST /job_accessories/:id/download_images' do
    let(:accessory) { create(:job_accessory) }
    let(:url) { "/api/v1/job_accessories/#{accessory.id}/download_images" }
    let(:valid_size) { 'grid' }

    it_behaves_like 'an async image download', DownloadJobAccessoryImagesJob
  end

  describe 'POST /artifacts/:id/download_images' do
    let(:artifact) { create(:artifact) }
    let(:url) { "/api/v1/artifacts/#{artifact.id}/download_images" }
    let(:valid_size) { 'wide' }

    it_behaves_like 'an async image download', DownloadArtifactImagesJob
  end
end
