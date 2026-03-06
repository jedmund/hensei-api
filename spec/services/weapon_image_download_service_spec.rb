# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeaponImageDownloadService do
  let(:weapon) { double('Weapon', granblue_id: '1040001000', transcendence: false) }
  let(:downloader_double) { double('WeaponDownloader', download: nil) }

  before do
    allow(Granblue::Downloaders::WeaponDownloader).to receive(:new).and_return(downloader_double)
    allow(Weapon).to receive(:element_changeable?).and_return(false)
  end

  describe '#download' do
    it 'returns successful result' do
      result = described_class.new(weapon).download
      expect(result.success?).to be true
    end

    context 'variant building' do
      it 'includes base variant without suffix' do
        result = described_class.new(weapon).download
        expect(result.images['main']).to include('1040001000.jpg')
      end

      it 'includes transcendence variants when transcendence is true' do
        allow(weapon).to receive(:transcendence).and_return(true)
        result = described_class.new(weapon).download

        aggregate_failures do
          expect(result.images['main']).to include('1040001000_02.jpg', '1040001000_03.jpg')
        end
      end

      it 'includes element variants for element-changeable weapons' do
        allow(Weapon).to receive(:element_changeable?).with(weapon).and_return(true)
        result = described_class.new(weapon).download

        (0..6).each do |element|
          expect(result.images['main']).to include("1040001000_#{element}.jpg")
        end
      end

      it 'uses png extension for base size' do
        result = described_class.new(weapon).download
        base_files = result.images['base']
        expect(base_files).to all(end_with('.png')) if base_files
      end
    end

    it 'returns failure result on error' do
      allow(downloader_double).to receive(:download).and_raise(StandardError, 'timeout')
      allow(Rails.logger).to receive(:error)

      result = described_class.new(weapon).download
      expect(result.success?).to be false
    end
  end
end
