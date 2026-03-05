# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Downloaders::DownloadManager do
  let(:downloader_double) { double('Downloader', download: nil) }

  before do
    allow(FileUtils).to receive(:mkdir_p)
    allow(Rails).to receive(:root).and_return(Pathname.new('/app'))
    allow(AwsService).to receive(:new).and_return(double('AwsService', file_exists?: false))
    Granblue::Downloaders::BaseDownloader.reset_aws_service
  end

  describe '.download_for_object' do
    it 'routes character type to CharacterDownloader' do
      allow(Granblue::Downloaders::CharacterDownloader).to receive(:new).and_return(downloader_double)
      described_class.download_for_object('character', '3040001000')
      expect(Granblue::Downloaders::CharacterDownloader).to have_received(:new).with('3040001000', hash_including(storage: :both))
    end

    it 'routes weapon type to WeaponDownloader' do
      allow(Granblue::Downloaders::WeaponDownloader).to receive(:new).and_return(downloader_double)
      described_class.download_for_object('weapon', '1040001000')
      expect(Granblue::Downloaders::WeaponDownloader).to have_received(:new).with('1040001000', hash_including(storage: :both))
    end

    it 'routes summon type to SummonDownloader' do
      allow(Granblue::Downloaders::SummonDownloader).to receive(:new).and_return(downloader_double)
      described_class.download_for_object('summon', '2040001000')
      expect(Granblue::Downloaders::SummonDownloader).to have_received(:new).with('2040001000', hash_including(storage: :both))
    end

    it 'does not raise for unknown type' do
      expect { described_class.download_for_object('artifact', '99999') }.not_to raise_error
    end

    it 'passes options through' do
      allow(Granblue::Downloaders::CharacterDownloader).to receive(:new).and_return(downloader_double)
      described_class.download_for_object('character', '3040001000', test_mode: true, verbose: true, storage: :s3)
      expect(Granblue::Downloaders::CharacterDownloader).to have_received(:new).with(
        '3040001000', hash_including(test_mode: true, verbose: true, storage: :s3)
      )
    end
  end
end
