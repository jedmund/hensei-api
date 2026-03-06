# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeaponSkillBoostType, type: :model do
  describe 'validations' do
    subject { build(:weapon_skill_boost_type) }

    it { is_expected.to validate_presence_of(:key) }
    it { is_expected.to validate_uniqueness_of(:key) }
    it { is_expected.to validate_presence_of(:name_en) }
    it { is_expected.to validate_presence_of(:category) }
    it { is_expected.to validate_inclusion_of(:category).in_array(described_class::CATEGORIES) }
    it { is_expected.to validate_presence_of(:stacking_rule) }
    it { is_expected.to validate_inclusion_of(:stacking_rule).in_array(described_class::STACKING_RULES) }
  end

  describe 'constants' do
    it 'defines valid categories' do
      expect(described_class::CATEGORIES).to eq(%w[offensive defensive multiattack cap supplemental utility])
    end

    it 'defines valid stacking rules' do
      expect(described_class::STACKING_RULES).to eq(%w[additive multiplicative_by_series highest_only])
    end
  end

  describe 'scopes' do
    let!(:capped) { create(:weapon_skill_boost_type, :with_cap) }
    let!(:uncapped) { create(:weapon_skill_boost_type, grid_cap: nil) }

    it '.capped returns records with a grid_cap' do
      expect(described_class.capped).to include(capped)
      expect(described_class.capped).not_to include(uncapped)
    end

    it '.by_category filters by category' do
      offensive = create(:weapon_skill_boost_type, :offensive)
      defensive = create(:weapon_skill_boost_type, :defensive)
      expect(described_class.by_category('offensive')).to include(offensive)
      expect(described_class.by_category('offensive')).not_to include(defensive)
    end
  end
end
