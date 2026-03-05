# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ArtifactImageDownloadService do
  let(:artifact) { double('Artifact', granblue_id: '30001') }
  let(:downloader_double) { double('ArtifactDownloader', download: nil) }

  before do
    allow(Granblue::Downloaders::ArtifactDownloader).to receive(:new).and_return(downloader_double)
  end

  describe '#download' do
    it 'returns successful result' do
      result = described_class.new(artifact).download

      aggregate_failures do
        expect(result.success?).to be true
        expect(result.error).to be_nil
        expect(result.images).to be_a(Hash)
      end
    end

    it 'builds manifest with one image per size' do
      result = described_class.new(artifact).download

      result.images.each_value do |filenames|
        expect(filenames).to eq(['30001.jpg'])
      end
    end

    it 'counts total images correctly' do
      result = described_class.new(artifact).download
      sizes_count = Granblue::Downloaders::ArtifactDownloader::SIZES.length
      expect(result.total).to eq(sizes_count)
    end

    it 'returns failure result on error' do
      allow(downloader_double).to receive(:download).and_raise(StandardError, 'network error')
      allow(Rails.logger).to receive(:error)

      result = described_class.new(artifact).download

      aggregate_failures do
        expect(result.success?).to be false
        expect(result.error).to eq('network error')
      end
    end

    it 'passes storage option to downloader' do
      described_class.new(artifact, storage: :local).download
      expect(Granblue::Downloaders::ArtifactDownloader).to have_received(:new).with(
        '30001', hash_including(storage: :local)
      )
    end
  end
end
