# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterImageDownloadService do
  let(:character) { double('Character', granblue_id: '3040001000', flb: false, transcendence: false, element: 1) }
  let(:downloader_double) { double('CharacterDownloader', download: nil) }

  before do
    allow(Granblue::Downloaders::CharacterDownloader).to receive(:new).and_return(downloader_double)
  end

  describe '#download' do
    it 'returns successful result' do
      result = described_class.new(character).download
      expect(result.success?).to be true
    end

    context 'variant building' do
      it 'includes _01 and _02 variants by default' do
        result = described_class.new(character).download
        main_files = result.images['main']
        expect(main_files).to include('3040001000_01.jpg', '3040001000_02.jpg')
        expect(main_files).not_to include('3040001000_03.jpg')
      end

      it 'includes _03 variant when flb is true' do
        allow(character).to receive(:flb).and_return(true)
        result = described_class.new(character).download
        expect(result.images['main']).to include('3040001000_03.jpg')
      end

      it 'includes _04 variant when transcendence is true' do
        allow(character).to receive(:transcendence).and_return(true)
        result = described_class.new(character).download
        expect(result.images['main']).to include('3040001000_04.jpg')
      end

      it 'uses png extension for detail size' do
        result = described_class.new(character).download
        detail_files = result.images['detail']
        expect(detail_files).to all(end_with('.png')) if detail_files
      end
    end

    it 'counts total images across all sizes' do
      result = described_class.new(character).download
      sizes_count = Granblue::Downloaders::CharacterDownloader::SIZES.length
      expect(result.total).to eq(2 * sizes_count) # 2 variants * sizes
    end

    context 'null-element characters' do
      let(:null_element_char) { double('Character', granblue_id: '3040643000', flb: false, transcendence: false, element: 0) }

      it 'includes element-suffixed variants for all 6 elements and both genders' do
        result = described_class.new(null_element_char).download
        main_files = result.images['main']
        # 2 base poses + 2 poses * 6 elements * 2 genders = 26 variants
        expect(main_files.length).to eq(26)
        expect(main_files).to include(
          '3040643000_01_01_0.jpg', '3040643000_01_01_1.jpg',
          '3040643000_02_06_0.jpg', '3040643000_02_06_1.jpg'
        )
      end
    end

    it 'returns failure result on error' do
      allow(downloader_double).to receive(:download).and_raise(StandardError, 'download failed')
      allow(Rails.logger).to receive(:error)

      result = described_class.new(character).download

      aggregate_failures do
        expect(result.success?).to be false
        expect(result.error).to eq('download failed')
      end
    end
  end
end
