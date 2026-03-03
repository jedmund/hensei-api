# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Character, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:character_series_memberships).dependent(:destroy) }
    it { is_expected.to have_many(:character_series_records).through(:character_series_memberships) }
  end

  describe 'validations' do
    it 'allows valid season values' do
      GranblueEnums::CHARACTER_SEASONS.each_value do |value|
        character = build(:character, season: value)
        expect(character).to be_valid
      end
    end

    it 'allows nil season' do
      character = build(:character, season: nil)
      expect(character).to be_valid
    end

    it 'rejects invalid season values' do
      character = build(:character, season: 999)
      expect(character).not_to be_valid
    end
  end

  describe '#seasonal?' do
    it 'returns true for seasonal characters' do
      character = build(:character, season: GranblueEnums::CHARACTER_SEASONS[:Summer])
      expect(character.seasonal?).to be true
    end

    it 'returns false when season is nil' do
      character = build(:character, season: nil)
      expect(character.seasonal?).to be false
    end
  end

  describe '#season_name' do
    it 'returns the season name as a string' do
      character = build(:character, season: GranblueEnums::CHARACTER_SEASONS[:Halloween])
      expect(character.season_name).to eq('Halloween')
    end

    it 'returns nil when season is nil' do
      character = build(:character, season: nil)
      expect(character.season_name).to be_nil
    end
  end

  describe '#series_names' do
    it 'returns series names from character_series_records' do
      character = create(:character)
      grand = create(:character_series, name_en: 'Grand', slug: "grand-#{SecureRandom.hex(4)}", order: 1)
      create(:character_series_membership, character: character, character_series: grand)
      expect(character.series_names).to include('Grand')
    end

    it 'returns empty array when no series assigned' do
      character = create(:character, series: nil)
      expect(character.series_names).to eq([])
    end
  end

  describe '#series=' do
    let(:character) { build(:character) }

    it 'assigns character series by slug' do
      series = create(:character_series, slug: "test-assign-#{SecureRandom.hex(4)}")
      character.series = [series.slug]
      expect(character.character_series_memberships.map(&:character_series)).to include(series)
    end

    it 'ignores blank values' do
      character.series = [nil, '', []]
      expect(character.character_series_memberships).to be_empty
    end

    it 'does nothing when passed nil' do
      character.series = nil
      expect(character.character_series_memberships).to be_empty
    end
  end
end
