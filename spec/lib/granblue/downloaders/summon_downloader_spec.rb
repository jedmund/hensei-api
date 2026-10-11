# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Downloaders::SummonDownloader do
  let(:cdn) { 'https://prd-game-a-granbluefantasy.akamaized.net/assets_en/img/sp/assets/summon' }
  let(:aws_double) { double('AwsService', file_exists?: false, upload_stream: nil) }
  let(:summon) { double('Summon', granblue_id: '2040330000', ulb: false, transcendence: false) }
  let(:opened_urls) { [] }

  before do
    allow(AwsService).to receive(:new).and_return(aws_double)
    described_class.reset_aws_service
    allow(Summon).to receive(:find_by).and_return(summon)

    # Stub the game CDN: record each URL and hand back a fake image stream
    allow(URI).to receive(:parse).and_wrap_original do |original, url|
      uri = original.call(url)
      next uri unless url.to_s.start_with?(cdn)

      opened_urls << url
      remote = double('RemoteImage')
      allow(remote).to receive(:open) { |&block| block ? block.call(StringIO.new('png')) : StringIO.new('png') }
      remote
    end
  end

  def downloader
    described_class.new(summon.granblue_id, storage: :s3, force: true)
  end

  describe 'SIZES' do
    it 'includes gacha alongside the existing sizes' do
      expect(described_class::SIZES).to eq(%w[main tall grid wide square detail gacha])
    end
  end

  describe '#build_variant_url' do
    it 'points gacha at the game g folder as png' do
      expect(downloader.send(:build_variant_url, '2040330000', 'gacha')).to eq("#{cdn}/g/2040330000.png")
    end

    it 'keeps detail as png and other sizes as jpg' do
      aggregate_failures do
        expect(downloader.send(:build_variant_url, '2040330000', 'detail')).to eq("#{cdn}/detail/2040330000.png")
        expect(downloader.send(:build_variant_url, '2040330000', 'main')).to eq("#{cdn}/party_main/2040330000.jpg")
      end
    end
  end

  describe '#download with the gacha size' do
    it 'uploads the g art to summons/gacha/{id}.png' do
      downloader.download('gacha')

      expect(opened_urls).to eq(["#{cdn}/g/2040330000.png"])
      expect(aws_double).to have_received(:upload_stream).with(anything, 'summons/gacha/2040330000.png')
    end

    it 'downloads the ULB and transcendence variants when the summon has them' do
      allow(summon).to receive_messages(ulb: true, transcendence: true)

      downloader.download('gacha')

      expect(opened_urls).to eq(%W[#{cdn}/g/2040330000.png #{cdn}/g/2040330000_02.png
                                   #{cdn}/g/2040330000_03.png #{cdn}/g/2040330000_04.png])
      %w[02 03 04].each do |suffix|
        expect(aws_double).to have_received(:upload_stream).with(anything, "summons/gacha/2040330000_#{suffix}.png")
      end
    end
  end
end
