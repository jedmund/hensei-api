# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SummonImageDownloadService do
  let(:summon) { double('Summon', granblue_id: '2040001000', ulb: false, transcendence: false) }
  let(:downloader_double) { double('SummonDownloader', download: nil) }

  before do
    allow(Granblue::Downloaders::SummonDownloader).to receive(:new).and_return(downloader_double)
  end

  describe '#download' do
    it 'returns successful result' do
      result = described_class.new(summon).download
      expect(result.success?).to be true
    end

    context 'variant building' do
      it 'includes base variant without suffix' do
        result = described_class.new(summon).download
        expect(result.images['main']).to include('2040001000.jpg')
      end

      it 'includes _02 variant when ulb is true' do
        allow(summon).to receive(:ulb).and_return(true)
        result = described_class.new(summon).download
        expect(result.images['main']).to include('2040001000_02.jpg')
      end

      it 'includes _03 and _04 variants when transcendence is true' do
        allow(summon).to receive(:transcendence).and_return(true)
        result = described_class.new(summon).download

        aggregate_failures do
          expect(result.images['main']).to include('2040001000_03.jpg', '2040001000_04.jpg')
        end
      end
    end

    it 'returns failure result on error' do
      allow(downloader_double).to receive(:download).and_raise(StandardError, 'S3 error')
      allow(Rails.logger).to receive(:error)

      result = described_class.new(summon).download
      expect(result.success?).to be false
      expect(result.error).to eq('S3 error')
    end
  end
end
