# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Downloaders::CharacterDownloader do
  let(:cdn) { 'https://prd-game-a-granbluefantasy.akamaized.net/assets_en/img/sp/assets/npc' }
  let(:aws_double) { instance_double(AwsService, file_exists?: false, upload_stream: nil) }
  let(:opened_urls) { [] }
  let(:poses) { %w[01 02] }
  let(:traits) { {} }
  let(:character) do
    instance_double(Character, { granblue_id: '3040001000', style_swap?: false, flb: false, ulb: false,
                                 transcendence: false, gender_variants?: false, element: 1 }.merge(traits))
  end

  before do
    allow(AwsService).to receive(:new).and_return(aws_double)
    described_class.reset_aws_service
    allow(Character).to receive(:find_by).with(granblue_id: '3040001000').and_return(character)

    # Stub the game CDN: record each URL and hand back a fake image stream
    allow(Granblue::Downloaders::RemoteFile).to receive(:open) do |url, &block|
      opened_urls << url
      block ? block.call(StringIO.new('img')) : StringIO.new('img')
    end
  end

  def grid_urls(*variants)
    variants.map { |variant| "#{cdn}/m/3040001000_#{variant}.jpg" }
  end

  def download(size = 'grid')
    described_class.new('3040001000', storage: :s3, force: true, logger: Logger.new(IO::NULL)).download(size)
    opened_urls
  end

  it 'keeps the sizes callers validate against' do
    expect(described_class::SIZES).to eq(%w[main grid square detail])
  end

  it 'does nothing for a character that is not in the database' do
    allow(Character).to receive(:find_by).with(granblue_id: '3040001000').and_return(nil)
    expect(download).to be_empty
  end

  it 'downloads the two base poses' do
    expect(download).to eq(grid_urls('01', '02'))
  end

  it 'downloads every size when none is selected' do
    expect(download(nil)).to eq(["#{cdn}/f/3040001000_01.jpg", "#{cdn}/m/3040001000_01.jpg", "#{cdn}/s/3040001000_01.jpg",
                                 "#{cdn}/detail/3040001000_01.png", "#{cdn}/f/3040001000_02.jpg",
                                 "#{cdn}/m/3040001000_02.jpg", "#{cdn}/s/3040001000_02.jpg",
                                 "#{cdn}/detail/3040001000_02.png"])
  end

  context 'with FLB' do
    let(:traits) { { flb: true } }

    it('adds the 03 pose') { expect(download).to eq(grid_urls('01', '02', '03')) }
  end

  context 'with ULB' do
    let(:traits) { { flb: true, ulb: true } }

    it('adds the 04 pose') { expect(download).to eq(grid_urls('01', '02', '03', '04')) }
  end

  context 'with transcendence but no ULB' do
    let(:traits) { { transcendence: true } }

    it('adds the 04 pose') { expect(download).to eq(grid_urls('01', '02', '04')) }
  end

  context 'with gender variants' do
    let(:traits) { { gender_variants?: true } }

    it 'adds a Gran and a Djeeta copy of each pose' do
      expect(download).to eq(grid_urls('01', '02', '01_0', '01_1', '02_0', '02_1'))
    end
  end

  context 'with a null element' do
    let(:traits) { { element: 0 } }

    it 'adds a copy of each pose per element' do
      element_variants = (1..6).flat_map { |element| poses.map { |pose| "#{pose}_0#{element}" } }
      expect(download).to eq(grid_urls('01', '02', *element_variants))
    end
  end

  context 'with a null element and gender variants' do
    let(:traits) { { element: 0, gender_variants?: true } }

    it 'adds a Gran and a Djeeta copy of each pose per element' do
      element_variants = (1..6).flat_map do |element|
        poses.flat_map { |pose| (0..1).map { |gender| "#{pose}_0#{element}_#{gender}" } }
      end
      expect(download).to eq(grid_urls('01', '02', '01_0', '01_1', '02_0', '02_1', *element_variants))
    end
  end

  context 'with a style swap' do
    let(:traits) { { style_swap?: true, flb: true, gender_variants?: true, element: 0 } }

    it 'downloads only the style art' do
      expect(download).to eq(["#{cdn}/m/3040001000_01_st2.jpg"])
    end
  end
end
