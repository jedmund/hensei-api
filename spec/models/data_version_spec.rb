# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DataVersion, type: :model do
  describe 'validations' do
    subject { build(:data_version) }

    it { is_expected.to validate_presence_of(:filename) }
    it { is_expected.to validate_uniqueness_of(:filename) }
    it { is_expected.to validate_presence_of(:imported_at) }
  end

  describe '.mark_as_imported' do
    it 'creates a record with the given filename and current time' do
      record = described_class.mark_as_imported('characters_v2.csv')
      expect(record).to be_persisted
      expect(record.filename).to eq('characters_v2.csv')
      expect(record.imported_at).to be_within(1.second).of(Time.current)
    end
  end

  describe '.imported?' do
    it 'returns true when the filename has been imported' do
      create(:data_version, filename: 'weapons.csv')
      expect(described_class.imported?('weapons.csv')).to be true
    end

    it 'returns false when the filename has not been imported' do
      expect(described_class.imported?('unknown.csv')).to be false
    end
  end
end
