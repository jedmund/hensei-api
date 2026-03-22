# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CrewRoster, type: :model do
  let(:crew) { create(:crew) }
  let(:user) { create(:user) }

  describe 'associations' do
    it { is_expected.to belong_to(:crew) }
    it { is_expected.to belong_to(:created_by).class_name('User') }
  end

  describe 'validations' do
    subject { build(:crew_roster, crew: crew, created_by: user) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
    it { is_expected.to validate_presence_of(:element) }

    it 'validates element uniqueness per crew' do
      create(:crew_roster, crew: crew, created_by: user, element: 2)
      duplicate = build(:crew_roster, crew: crew, created_by: user, element: 2)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:element]).to be_present
    end

    it 'allows same element across different crews' do
      other_crew = create(:crew)
      create(:crew_roster, crew: crew, created_by: user, element: 2)
      other_roster = build(:crew_roster, crew: other_crew, created_by: user, element: 2)

      expect(other_roster).to be_valid
    end

    it 'rejects invalid element values' do
      roster = build(:crew_roster, crew: crew, created_by: user, element: 7)
      expect(roster).not_to be_valid
    end

    it 'rejects element 0 (null element)' do
      roster = build(:crew_roster, crew: crew, created_by: user, element: 0)
      expect(roster).not_to be_valid
    end
  end

  describe 'items validation' do
    it 'accepts empty items array' do
      roster = build(:crew_roster, crew: crew, created_by: user, items: [])
      expect(roster).to be_valid
    end

    it 'accepts valid item hashes' do
      roster = build(:crew_roster, crew: crew, created_by: user,
                                   items: [{ 'id' => 'abc', 'type' => 'Character' }])
      expect(roster).to be_valid
    end

    it 'rejects items missing id' do
      roster = build(:crew_roster, crew: crew, created_by: user,
                                   items: [{ 'type' => 'Character' }])
      expect(roster).not_to be_valid
    end

    it 'rejects items missing type' do
      roster = build(:crew_roster, crew: crew, created_by: user,
                                   items: [{ 'id' => 'abc' }])
      expect(roster).not_to be_valid
    end
  end

  describe '.seed_for_crew!' do
    it 'creates one roster per element' do
      expect {
        described_class.seed_for_crew!(crew, user)
      }.to change(described_class, :count).by(6)

      expect(crew.crew_rosters.pluck(:element).sort).to eq([1, 2, 3, 4, 5, 6])
    end

    it 'is idempotent' do
      described_class.seed_for_crew!(crew, user)

      expect {
        described_class.seed_for_crew!(crew, user)
      }.not_to change(described_class, :count)
    end
  end

  describe 'defaults' do
    it 'initializes items to empty array' do
      roster = described_class.new
      expect(roster.items).to eq([])
    end
  end
end
