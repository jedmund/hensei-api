# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RaidGroup, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:raids).class_name('Raid').with_foreign_key(:group_id).dependent(:restrict_with_error) }
  end

  describe 'validations' do
    subject { build(:raid_group) }

    it { is_expected.to validate_presence_of(:name_en) }
    it { is_expected.to validate_presence_of(:name_jp) }
    it { is_expected.to validate_presence_of(:order) }
    it { is_expected.to validate_numericality_of(:order).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_presence_of(:section) }
    it { is_expected.to validate_numericality_of(:section).only_integer.is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:difficulty).only_integer.allow_nil }
  end

  describe 'scopes' do
    let!(:group_a) { create(:raid_group, order: 1, section: 1, hl: true, extra: false, guidebooks: false, unlimited: false) }
    let!(:group_b) { create(:raid_group, order: 2, section: 2, hl: false, extra: true, guidebooks: true, unlimited: true) }

    it '.ordered sorts by order ascending' do
      expect(described_class.ordered).to eq([group_a, group_b])
    end

    it '.by_section filters by section' do
      expect(described_class.by_section(1)).to include(group_a)
      expect(described_class.by_section(1)).not_to include(group_b)
    end

    it '.hl_only returns groups with hl true' do
      expect(described_class.hl_only).to include(group_a)
      expect(described_class.hl_only).not_to include(group_b)
    end

    it '.extra_only returns groups with extra true' do
      expect(described_class.extra_only).to include(group_b)
      expect(described_class.extra_only).not_to include(group_a)
    end

    it '.with_guidebooks returns groups with guidebooks true' do
      expect(described_class.with_guidebooks).to include(group_b)
      expect(described_class.with_guidebooks).not_to include(group_a)
    end

    it '.unlimited_only returns groups with unlimited true' do
      expect(described_class.unlimited_only).to include(group_b)
      expect(described_class.unlimited_only).not_to include(group_a)
    end
  end

  describe 'dependent restrict' do
    it 'prevents deletion when raids exist' do
      group = create(:raid_group)
      create(:raid, group: group)
      expect { group.destroy }.not_to change(described_class, :count)
      expect(group.errors[:base]).to be_present
    end
  end
end
