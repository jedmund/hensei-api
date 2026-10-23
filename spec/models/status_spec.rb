# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Status, type: :model do
  subject { build(:status) }

  describe 'associations' do
    it { is_expected.to have_many(:skill_effects).dependent(:nullify) }
  end

  describe 'enums' do
    it 'defines category enum' do
      expect(described_class.categories).to eq(
        'buff' => 'buff',
        'debuff' => 'debuff',
        'field' => 'field',
        'special' => 'special'
      )
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name_en) }
    it { is_expected.to validate_uniqueness_of(:game_ailment_id).allow_nil }
  end

  describe '.in_family' do
    it 'returns statuses in the requested family' do
      paralyzed = create(:status, name_en: 'Paralyzed 1', family: 'Paralyzed', level: 1)
      create(:status, name_en: 'ATK Up', family: 'ATK Up')

      expect(described_class.in_family('Paralyzed')).to contain_exactly(paralyzed)
    end
  end

  describe '.normalize_name and name_key' do
    it 'squishes any whitespace and downcases non-ASCII letters, whatever the database locale' do
      expect(described_class.normalize_name("\tÄRGER\n Up ")).to eq('ärger up')
      expect(described_class.normalize_name("A\u0308rger")).to eq('ärger') # decomposed Ä
    end

    it 'stores the key and finds the status by any spelling of it' do
      status = create(:status, name_en: "Ärger\tUp")
      expect(status.name_key).to eq('ärger up')
      expect(described_class.named(['ÄRGER  UP'])).to eq([status])
    end

    it 'keys a status by its wiki name, so its shown name can drop the number (D59)' do
      status = create(:status, wiki_name: 'Jade Crest 1', name_en: 'Jade Crest')
      expect(status.name_key).to eq('jade crest 1')
      expect(create(:status, name_en: 'Veil').wiki_name).to eq('Veil')
    end

    it 'refuses two statuses with the same shown name and qualifier' do
      create(:status, wiki_name: 'Asleep', name_en: 'Asleep')
      create(:status, wiki_name: 'Asleep 1', name_en: 'Asleep', qualifier: 'Turns')
      expect { create(:status, wiki_name: 'Asleep 2', name_en: 'Asleep') }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'refuses a second status with the same key' do
      create(:status, name_en: 'Ärger Up')
      expect { create(:status, name_en: " ÄRGER\nup") }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
