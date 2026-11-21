# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Downloaders::WonderDownloader do
  subject(:downloader) { described_class.new(wonder.granblue_id, storage: :local) }

  describe '#image_names' do
    context 'with a leveled Wonder' do
      let(:wonder) { build(:wonder, granblue_id: '9008', kind: 'leveled', max_level: 20) }

      it 'lists the base art and every level' do
        names = downloader.image_names(wonder)
        expect(names.first).to eq('9008')
        expect(names).to include('9008_1', '9008_20')
        expect(names.size).to eq(21)
      end
    end

    context 'with the scaling Wonder' do
      let(:wonder) { build(:wonder, granblue_id: '9015', kind: 'scaling') }

      it 'probes the numbered variants' do
        expect(downloader.image_names(wonder)).to include('9015', '9015_2', '9015_12')
      end
    end

    context 'with a fixed Wonder' do
      let(:wonder) { build(:wonder, granblue_id: '2003', kind: 'fixed') }

      it 'lists only the base art' do
        expect(downloader.image_names(wonder)).to eq(['2003'])
      end
    end
  end

  describe 'storage keys' do
    let(:wonder) { build(:wonder, granblue_id: '9008', kind: 'leveled', max_level: 20) }

    it 'stores files directly under wonders/' do
      expect(downloader.send(:build_s3_key, 'square', '9008_20.jpg')).to eq('wonders/9008_20.jpg')
    end
  end
end
