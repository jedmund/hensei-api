# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Downloaders::ElementalWeaponDownloader do
  let(:cdn) { 'https://prd-game-a-granbluefantasy.akamaized.net/assets_en/img/sp/assets/weapon' }

  before do
    allow(FileUtils).to receive(:mkdir_p)
    allow(AwsService).to receive(:new)
  end

  describe '#initialize' do
    it 'creates the local download directories without connecting to S3' do
      described_class.new('1040001000')

      expect(FileUtils).to have_received(:mkdir_p).exactly(Granblue::Downloaders::WeaponDownloader::SIZES.size).times
      expect(AwsService).not_to have_received(:new)
    end
  end

  describe '#download' do
    it 'steps the weapon id by 100 for each element' do
      downloader = described_class.new('1040001000')
      allow(downloader).to receive(:download_elemental_image)
      allow(downloader).to receive(:print)
      allow(downloader).to receive(:puts)

      downloader.download

      %w[1040001000_1 1040001100_2 1040001200_3 1040001300_4 1040001400_5 1040001500_6].each do |stem|
        id = stem.split('_').first
        expect(downloader).to have_received(:download_elemental_image)
          .with("#{cdn}/ls/#{id}.jpg", 'main', anything, "#{stem}.jpg")
      end
    end
  end
end
