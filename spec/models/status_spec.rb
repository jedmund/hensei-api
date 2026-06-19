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
end
