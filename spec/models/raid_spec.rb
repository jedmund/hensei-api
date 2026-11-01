# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Raid, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:group).class_name('RaidGroup') }
  end

  describe 'validations' do
    subject { build(:raid) }

    it { is_expected.to validate_presence_of(:name_en) }
    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_uniqueness_of(:slug) }
    it { is_expected.to validate_presence_of(:group_id) }
    it { is_expected.to validate_inclusion_of(:player_count).in_array([1, 6, 18, 30]) }

    %i[enemy_id summon_id quest_id].each do |attribute|
      it { is_expected.to validate_numericality_of(attribute).only_integer.is_greater_than(0).allow_nil }
    end

    it 'accepts lowercase hyphenated slugs only' do
      slug_errors = ->(slug) { build(:raid, slug: slug).tap(&:validate).errors[:slug] }
      %w[lucilius-hard tiamat-omega-2 bahamut].each { |slug| expect(slug_errors.call(slug)).to be_empty }
      ['Lucilius', 'lucilius hard', 'lucilius--hard', '-lucilius', 'lucilius_hard'].each do |slug|
        expect(slug_errors.call(slug)).to include('is invalid')
      end
    end

    it 'allows element values between 0 and 6' do
      group = create(:raid_group)
      (0..6).each do |e|
        raid = build(:raid, element: e, group: group)
        expect(raid).to be_valid
      end
    end

    it 'rejects element values outside 0-6' do
      group = create(:raid_group)
      raid = build(:raid, element: 7, group: group)
      expect(raid).not_to be_valid
    end

    it 'allows nil element' do
      group = create(:raid_group)
      raid = build(:raid, element: nil, group: group)
      expect(raid).to be_valid
    end

    it 'validates level is a non-negative integer when present' do
      group = create(:raid_group)
      expect(build(:raid, level: -1, group: group)).not_to be_valid
      expect(build(:raid, level: 0, group: group)).to be_valid
      expect(build(:raid, level: 150, group: group)).to be_valid
      expect(build(:raid, level: nil, group: group)).to be_valid
    end
  end

  describe 'scopes' do
    let!(:group) { create(:raid_group, order: 1) }
    let!(:fire_raid) { create(:raid, :fire, group: group) }
    let!(:water_raid) { create(:raid, :water, group: group) }

    it '.by_element filters by element' do
      expect(described_class.by_element(1)).to include(fire_raid)
      expect(described_class.by_element(1)).not_to include(water_raid)
    end

    it '.by_group filters by group_id' do
      other_group = create(:raid_group, order: 2)
      other_raid = create(:raid, group: other_group)
      expect(described_class.by_group(group.id)).to include(fire_raid)
      expect(described_class.by_group(group.id)).not_to include(other_raid)
    end
  end
end
