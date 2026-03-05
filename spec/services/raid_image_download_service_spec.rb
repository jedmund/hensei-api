# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RaidImageDownloadService do
  let(:raid) { double('Raid', slug: 'proto-bahamut', enemy_id: '301061', summon_id: '2040056000', quest_id: '303141') }
  let(:downloader_double) { double('RaidDownloader', download: nil) }

  before do
    allow(Granblue::Downloaders::RaidDownloader).to receive(:new).and_return(downloader_double)
  end

  describe '#download' do
    it 'returns successful result' do
      result = described_class.new(raid).download
      expect(result.success?).to be true
    end

    context 'manifest building' do
      it 'includes icon from enemy_id' do
        result = described_class.new(raid).download
        expect(result.images['icon']).to eq(['301061.png'])
      end

      it 'includes thumbnail from summon_id' do
        result = described_class.new(raid).download
        expect(result.images['thumbnail']).to eq(['2040056000_high.png'])
      end

      it 'includes lobby and background from quest_id' do
        result = described_class.new(raid).download

        aggregate_failures do
          expect(result.images['lobby']).to eq(['3031411.png'])
          expect(result.images['background']).to eq(['303141_raid_image_new.png'])
        end
      end

      it 'omits keys for nil IDs' do
        raid_no_enemy = double('Raid', slug: 'test', enemy_id: nil, summon_id: nil, quest_id: '100')
        result = described_class.new(raid_no_enemy).download

        aggregate_failures do
          expect(result.images).not_to have_key('icon')
          expect(result.images).not_to have_key('thumbnail')
          expect(result.images).to have_key('lobby')
        end
      end
    end

    it 'counts total images correctly' do
      result = described_class.new(raid).download
      expect(result.total).to eq(4) # icon + thumbnail + lobby + background
    end

    it 'returns failure result on error' do
      allow(downloader_double).to receive(:download).and_raise(StandardError, 'error')
      allow(Rails.logger).to receive(:error)

      result = described_class.new(raid).download
      expect(result.success?).to be false
    end
  end
end
