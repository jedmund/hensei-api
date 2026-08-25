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

    it 'requires an explicit released stage when transcendence is enabled' do
      character = build(:character, transcendence: true, max_transcendence_stage: 0)

      expect(character).not_to be_valid
      expect(character.errors[:max_transcendence_stage]).to include(
        'must be between 1 and 5 when transcendence is enabled'
      )
    end

    it 'normalizes the released stage to zero when transcendence is disabled' do
      character = build(:character, transcendence: false, max_transcendence_stage: 5)

      expect(character).to be_valid
      expect(character.max_transcendence_stage).to eq(0)
    end

    it 'allows ULB only for special FLB characters' do
      expect(build(:character, :special_ulb)).to be_valid
      expect(build(:character, ulb: true, special: false)).not_to be_valid
      expect(build(:character, ulb: true, special: true, flb: false)).not_to be_valid
    end

    it 'does not allow special characters to use transcendence' do
      character = build(:character, special: true, transcendence: true, max_transcendence_stage: 1)

      expect(character).not_to be_valid
      expect(character.errors[:transcendence]).to include('is not supported for special characters')
    end
  end

  describe '#max_uncap_level' do
    it 'uses the distinct regular and special progressions' do
      expect(build(:character, :transcendable, max_transcendence_stage: 1).max_uncap_level).to eq(6)
      expect(build(:character, :special_ulb).max_uncap_level).to eq(5)
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

  describe 'scopes' do
    let!(:summer_char) { create(:character, season: GranblueEnums::CHARACTER_SEASONS[:Summer]) }
    let!(:halloween_char) { create(:character, season: GranblueEnums::CHARACTER_SEASONS[:Halloween]) }
    let!(:standard_char) { create(:character, season: nil) }

    it '.by_season filters by season value' do
      expect(Character.by_season(GranblueEnums::CHARACTER_SEASONS[:Summer])).to include(summer_char)
      expect(Character.by_season(GranblueEnums::CHARACTER_SEASONS[:Summer])).not_to include(halloween_char, standard_char)
    end

    it '.seasonal returns non-standard seasonal characters' do
      expect(Character.seasonal).to include(summer_char, halloween_char)
      expect(Character.seasonal).not_to include(standard_char)
    end

    describe '.by_series' do
      let!(:grand_series) { create(:character_series, :grand) }
      let!(:eternal_series) { create(:character_series, :eternal) }
      let!(:grand_char) { create(:character) }
      let!(:eternal_char) { create(:character) }
      let!(:both_char) { create(:character) }
      let!(:no_series_char) { create(:character) }

      before do
        create(:character_series_membership, character: grand_char, character_series: grand_series)
        create(:character_series_membership, character: eternal_char, character_series: eternal_series)
        create(:character_series_membership, character: both_char, character_series: grand_series)
        create(:character_series_membership, character: both_char, character_series: eternal_series)
      end

      it 'filters by single series' do
        results = Character.by_series([grand_series.id])
        expect(results).to include(grand_char, both_char)
        expect(results).not_to include(eternal_char, no_series_char)
      end

      it 'filters by multiple series (OR logic)' do
        results = Character.by_series([grand_series.id, eternal_series.id])
        expect(results).to include(grand_char, eternal_char, both_char)
        expect(results).not_to include(no_series_char)
      end

      it 'does not return duplicates for characters in multiple matched series' do
        results = Character.by_series([grand_series.id, eternal_series.id])
        expect(results.where(id: both_char.id).count).to eq(1)
      end
    end
  end

  describe 'search' do
    it 'can search by English name' do
      character = create(:character, name_en: 'Unique Character Name')
      results = Character.en_search('Unique Character')
      expect(results).to include(character)
    end
  end

  describe '#series=' do
    let(:character) { build(:character) }

    it 'assigns character series by slug' do
      series = create(:character_series, slug: "test-assign-#{SecureRandom.hex(4)}")
      character.series = [series.slug]
      expect(character.character_series_memberships.map(&:character_series)).to include(series)
    end

    it 'assigns character series by UUID' do
      series = create(:character_series, slug: "test-uuid-#{SecureRandom.hex(4)}")
      character.series = [series.id]
      expect(character.character_series_memberships.map(&:character_series)).to include(series)
    end

    it 'assigns multiple series at once' do
      s1 = create(:character_series, slug: "multi-a-#{SecureRandom.hex(4)}")
      s2 = create(:character_series, slug: "multi-b-#{SecureRandom.hex(4)}")
      character.series = [s1.id, s2.id]
      expect(character.character_series_memberships.map(&:character_series_id)).to contain_exactly(s1.id, s2.id)
    end

    it 'ignores blank values' do
      character.series = [nil, '', []]
      expect(character.character_series_memberships).to be_empty
    end

    it 'does nothing when passed nil' do
      character.series = nil
      expect(character.character_series_memberships).to be_empty
    end

    context 'on a persisted character' do
      let(:character) { create(:character) }
      let!(:grand) { create(:character_series, slug: "grand-sync-#{SecureRandom.hex(4)}") }
      let!(:eternal) { create(:character_series, slug: "eternal-sync-#{SecureRandom.hex(4)}") }
      let!(:zodiac) { create(:character_series, slug: "zodiac-sync-#{SecureRandom.hex(4)}") }

      it 'removes old memberships not in the new list' do
        character.series = [grand.id, eternal.id]
        character.save!

        character.series = [zodiac.id]
        character.save!

        character.reload
        expect(character.character_series_records).to contain_exactly(zodiac)
      end

      it 'keeps existing memberships that are still in the new list' do
        character.series = [grand.id, eternal.id]
        character.save!

        character.series = [grand.id, zodiac.id]
        character.save!

        character.reload
        expect(character.character_series_records).to contain_exactly(grand, zodiac)
      end

      it 'clears all memberships when passed blank' do
        character.series = [grand.id]
        character.save!

        character.series = []
        character.reload
        expect(character.character_series_records).to be_empty
      end
    end
  end
end
