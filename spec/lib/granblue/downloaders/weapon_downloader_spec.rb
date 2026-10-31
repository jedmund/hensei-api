# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Downloaders::WeaponDownloader do
  let(:cdn) { 'https://prd-game-a-granbluefantasy.akamaized.net/assets_en/img/sp/assets/weapon' }
  let(:aws_double) { double('AwsService', file_exists?: false, upload_stream: nil) }
  let(:weapon) do
    double('Weapon', granblue_id: '1040515700', name_en: 'Raffiniert Arquebus',
                     transcendence: false, element_variant_ids: nil)
  end
  let(:opened_urls) { [] }
  let(:missing_urls) { [] }

  before do
    allow(AwsService).to receive(:new).and_return(aws_double)
    described_class.reset_aws_service
    allow(Weapon).to receive(:find_by).and_return(weapon)
    allow(Weapon).to receive(:element_changeable?).and_return(false)

    # Stub the game CDN: record each URL and hand back a stream whose body is that URL,
    # so each upload can be matched to the source it came from
    allow(Granblue::Downloaders::RemoteFile).to receive(:open) do |url, &block|
      opened_urls << url
      raise Granblue::Downloaders::RemoteFile::HTTPError.new('404 Not Found', StringIO.new) if missing_urls.include?(url)

      block ? block.call(StringIO.new(url)) : StringIO.new(url)
    end
  end

  def downloader(id = weapon.granblue_id)
    described_class.new(id, storage: :s3, force: true)
  end

  describe 'SIZES' do
    it 'includes gacha alongside the existing sizes' do
      expect(described_class::SIZES).to eq(%w[main grid square base gacha])
    end
  end

  describe '#build_variant_url' do
    it 'points gacha at the game g folder as png' do
      expect(downloader.send(:build_variant_url, '1040515700', 'gacha')).to eq("#{cdn}/g/1040515700.png")
    end

    it 'keeps base as png and other sizes as jpg' do
      aggregate_failures do
        expect(downloader.send(:build_variant_url, '1040515700', 'base')).to eq("#{cdn}/b/1040515700.png")
        expect(downloader.send(:build_variant_url, '1040515700', 'main')).to eq("#{cdn}/ls/1040515700.jpg")
      end
    end
  end

  describe '#download with the gacha size' do
    it 'uploads the g art to weapons/gacha/{id}.png' do
      downloader.download('gacha')

      expect(opened_urls).to eq(["#{cdn}/g/1040515700.png"])
      expect(aws_double).to have_received(:upload_stream).with(anything, 'weapons/gacha/1040515700.png')
    end

    it 'downloads transcendence variants when the weapon has them' do
      allow(weapon).to receive(:transcendence).and_return(true)

      downloader.download('gacha')

      expect(opened_urls).to eq(%W[#{cdn}/g/1040515700.png #{cdn}/g/1040515700_02.png #{cdn}/g/1040515700_03.png])
      expect(aws_double).to have_received(:upload_stream).with(anything, 'weapons/gacha/1040515700_02.png')
      expect(aws_double).to have_received(:upload_stream).with(anything, 'weapons/gacha/1040515700_03.png')
    end

    context 'with an element-changeable weapon' do
      let(:weapon) do
        double('Weapon', granblue_id: '1040501700', name_en: 'Ten-Wolf Gun (Awakened)',
                         transcendence: false, element_variant_ids: nil)
      end

      before { allow(Weapon).to receive(:element_changeable?).with(weapon).and_return(true) }

      it 'downloads offset source ids and stores them under the element-suffixed key' do
        downloader.download('gacha')

        aggregate_failures do
          # Fire is the base id and is stored as _1
          expect(opened_urls).to include("#{cdn}/g/1040501700.png")
          expect(aws_double).to have_received(:upload_stream).with(anything, 'weapons/gacha/1040501700_1.png')
          # Null comes from the _note art and is stored as _0
          expect(opened_urls).to include("#{cdn}/g/1040501700_note.png")
          expect(aws_double).to have_received(:upload_stream).with(anything, 'weapons/gacha/1040501700_0.png')
        end
      end

      it 'reads Earth from +300 and Wind from +200 for the Revenant weapons' do
        downloader.download('gacha')

        aggregate_failures do
          expect(aws_double).to have_received(:upload_stream)
            .with(have_attributes(string: "#{cdn}/g/1040502000.png"), 'weapons/gacha/1040501700_3.png')
          expect(aws_double).to have_received(:upload_stream)
            .with(have_attributes(string: "#{cdn}/g/1040501900.png"), 'weapons/gacha/1040501700_4.png')
        end
      end

      context 'with a weapon on the standard element order' do
        let(:weapon) do
          double('Weapon', granblue_id: '1040011300', name_en: 'Atma Sword',
                           transcendence: false, element_variant_ids: nil)
        end

        it 'reads Earth from +200 and Wind from +300' do
          downloader.download('gacha')

          aggregate_failures do
            expect(aws_double).to have_received(:upload_stream)
              .with(have_attributes(string: "#{cdn}/g/1040011500.png"), 'weapons/gacha/1040011300_3.png')
            expect(aws_double).to have_received(:upload_stream)
              .with(have_attributes(string: "#{cdn}/g/1040011600.png"), 'weapons/gacha/1040011300_4.png')
          end
        end
      end

      it 'uses explicit element variant ids as both source and key' do
        allow(weapon).to receive(:element_variant_ids).and_return({ '1' => '1040804100' })

        downloader.download('gacha')

        expect(opened_urls).to include("#{cdn}/g/1040804100.png")
        expect(aws_double).to have_received(:upload_stream).with(anything, 'weapons/gacha/1040804100.png')
      end
    end

    it 'skips a variant the game does not serve' do
      allow(weapon).to receive(:transcendence).and_return(true)
      missing_urls << "#{cdn}/g/1040515700_02.png"

      expect { downloader.download('gacha') }.not_to raise_error
      expect(aws_double).not_to have_received(:upload_stream).with(anything, 'weapons/gacha/1040515700_02.png')
      expect(aws_double).to have_received(:upload_stream).with(anything, 'weapons/gacha/1040515700_03.png')
    end
  end
end
