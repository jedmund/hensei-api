# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ArtifactSkill, type: :model do
  describe 'validations' do
    subject { build(:artifact_skill) }

    it { is_expected.to validate_presence_of(:skill_group) }
    it { is_expected.to validate_presence_of(:modifier) }
    it { is_expected.to validate_presence_of(:name_en) }
    it { is_expected.to validate_presence_of(:name_jp) }
    it { is_expected.to validate_presence_of(:polarity) }

    it 'validates uniqueness of modifier within skill_group' do
      # Create with unique modifier, then try to create duplicate
      create(:artifact_skill, skill_group: :group_i, modifier: 5000)
      duplicate = build(:artifact_skill, skill_group: :group_i, modifier: 5000)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:modifier]).to include('has already been taken')
    end

    it 'allows same modifier in different skill groups' do
      create(:artifact_skill, skill_group: :group_i, modifier: 5001)
      different_group = build(:artifact_skill, skill_group: :group_ii, modifier: 5001)
      expect(different_group).to be_valid
    end

    it 'takes only known groups and polarities' do
      skill = build(:artifact_skill, skill_group: 'group_iv', polarity: 'neutral')
      expect(skill).not_to be_valid
      expect(skill.errors.attribute_names).to include(:skill_group, :polarity)
    end

    it 'needs the modifier to be a positive whole number' do
      [0, -1, 1.5].each do |modifier|
        expect(build(:artifact_skill, modifier: modifier)).not_to be_valid
      end
      expect(build(:artifact_skill, modifier: 29)).to be_valid
    end

    it 'takes a numeric or blank growth, negative included' do
      expect(build(:artifact_skill, growth: 'fast')).not_to be_valid
      expect(build(:artifact_skill, growth: -1)).to be_valid
      expect(build(:artifact_skill, growth: nil)).to be_valid
    end

    it 'takes a score category of 1 to 3, or none' do
      expect(build(:artifact_skill, score_category: 4)).not_to be_valid
      [1, 2, 3, nil].each { |category| expect(build(:artifact_skill, score_category: category)).to be_valid }
    end

    it 'takes up to five base values, numbers or unknown (null)' do
      [[], [10], [0.2, nil], [1320, 1440, 1560, 1680, 1800]].each do |values|
        expect(build(:artifact_skill, base_values: values)).to be_valid
      end
      [[1, 2, 3, 4, 5, 6], [1, '2'], [{ 'a' => 1 }], 'big'].each do |values|
        skill = build(:artifact_skill, base_values: values)
        expect(skill).not_to be_valid
        expect(skill.errors[:base_values]).to be_present
      end
    end
  end

  describe 'enums' do
    it 'defines skill_group enum' do
      expect(described_class.skill_groups).to eq(
        'group_i' => 1,
        'group_ii' => 2,
        'group_iii' => 3
      )
    end

    it 'defines polarity enum' do
      expect(described_class.polarities).to eq(
        'positive' => 'positive',
        'negative' => 'negative'
      )
    end
  end

  describe '.for_slot' do
    # Use unique modifiers that won't conflict with seeded data
    let!(:group_i_skill) { create(:artifact_skill, :group_i, modifier: 6000) }
    let!(:group_ii_skill) { create(:artifact_skill, :group_ii, modifier: 6001) }
    let!(:group_iii_skill) { create(:artifact_skill, :group_iii, modifier: 6002) }

    it 'returns Group I skills for slot 1' do
      expect(described_class.for_slot(1)).to include(group_i_skill)
      expect(described_class.for_slot(1)).not_to include(group_ii_skill)
    end

    it 'returns Group I skills for slot 2' do
      expect(described_class.for_slot(2)).to include(group_i_skill)
      expect(described_class.for_slot(2)).not_to include(group_ii_skill)
    end

    it 'returns Group II skills for slot 3' do
      expect(described_class.for_slot(3)).to include(group_ii_skill)
      expect(described_class.for_slot(3)).not_to include(group_i_skill)
    end

    it 'returns Group III skills for slot 4' do
      expect(described_class.for_slot(4)).to include(group_iii_skill)
      expect(described_class.for_slot(4)).not_to include(group_i_skill)
    end
  end

  describe '.find_skill' do
    let(:test_skill) { create(:artifact_skill, skill_group: :group_i, modifier: 7000) }

    before do
      described_class.clear_cache!
      test_skill
    end

    after do
      described_class.clear_cache!
    end

    it 'finds skill by group number and modifier' do
      described_class.clear_cache!
      found = described_class.find_skill(1, 7000)
      expect(found).to eq(test_skill)
    end

    it 'returns nil for non-existent skill' do
      described_class.clear_cache!
      expect(described_class.find_skill(1, 99999)).to be_nil
    end

    it 'caches skills for performance' do
      described_class.clear_cache!
      described_class.find_skill(1, 7000)
      expect(described_class.instance_variable_get(:@cached_skills)).not_to be_nil
    end
  end

  describe '.find_by_game_name' do
    after { described_class.clear_cache! }

    it 'sees skills added after clear_cache!' do
      described_class.clear_cache!
      expect(described_class.find_by_game_name('Cache Probe')).to be_nil
      skill = create(:artifact_skill, game_name_en: 'Cache Probe')
      expect(described_class.find_by_game_name('Cache Probe')).to be_nil
      described_class.clear_cache!
      expect(described_class.find_by_game_name('Cache Probe')).to eq(skill)
    end
  end

  describe '#calculate_value' do
    let(:skill) { build(:artifact_skill, growth: 300.0) }

    it 'returns base strength at level 1' do
      expect(skill.calculate_value(1800, 1)).to eq(1800)
    end

    it 'adds growth for each level above 1' do
      expect(skill.calculate_value(1800, 3)).to eq(2400) # 1800 + (300 * 2)
    end

    it 'handles level 5' do
      expect(skill.calculate_value(1800, 5)).to eq(3000) # 1800 + (300 * 4)
    end

    context 'with nil growth' do
      let(:skill) { build(:artifact_skill, :no_growth) }

      it 'returns base strength regardless of level' do
        expect(skill.calculate_value(10, 1)).to eq(10)
        expect(skill.calculate_value(10, 5)).to eq(10)
      end
    end

    context 'with negative growth' do
      let(:skill) { build(:artifact_skill, :negative, growth: -6.0) }

      it 'subtracts growth for each level' do
        expect(skill.calculate_value(30, 3)).to eq(18) # 30 + (-6 * 2)
      end
    end
  end

  describe '#format_value' do
    context 'with percentage suffix' do
      let(:skill) { build(:artifact_skill, suffix_en: '%', suffix_jp: '%') }

      it 'formats with English suffix' do
        expect(skill.format_value(18.0, :en)).to eq('18.0%')
      end

      it 'formats with Japanese suffix' do
        expect(skill.format_value(18.0, :jp)).to eq('18.0%')
      end
    end

    context 'with no suffix' do
      let(:skill) { build(:artifact_skill, suffix_en: '', suffix_jp: '') }

      it 'returns value without suffix' do
        expect(skill.format_value(1800, :en)).to eq('1800')
      end
    end
  end

  describe '#valid_strength?' do
    let(:skill) { build(:artifact_skill, base_values: [1320, 1440, 1560, 1680, 1800]) }

    it 'returns true for valid base values' do
      expect(skill.valid_strength?(1800)).to be true
      expect(skill.valid_strength?(1320)).to be true
    end

    it 'returns false for invalid values' do
      expect(skill.valid_strength?(1500)).to be false
      expect(skill.valid_strength?(9999)).to be false
    end

    context 'with nil in base_values (unknown values)' do
      let(:skill) { build(:artifact_skill, base_values: [nil]) }

      it 'returns true for any value' do
        expect(skill.valid_strength?(9999)).to be true
      end
    end
  end
end
