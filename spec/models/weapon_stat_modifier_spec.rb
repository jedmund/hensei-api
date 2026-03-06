# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeaponStatModifier, type: :model do
  describe 'validations' do
    subject { build(:weapon_stat_modifier) }

    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_uniqueness_of(:slug) }
    it { is_expected.to validate_presence_of(:name_en) }
    it { is_expected.to validate_presence_of(:category) }
    it { is_expected.to validate_inclusion_of(:category).in_array(described_class::CATEGORIES) }
    it { is_expected.to validate_inclusion_of(:polarity).in_array([-1, 1]) }
  end

  describe 'constants' do
    it 'defines valid categories' do
      expect(described_class::CATEGORIES).to eq(%w[ax befoulment])
    end
  end

  describe 'scopes' do
    let!(:ax) { create(:weapon_stat_modifier, :ax_atk) }
    let!(:befoulment) { create(:weapon_stat_modifier, :befoulment) }

    it '.ax_skills returns ax category modifiers' do
      expect(described_class.ax_skills).to include(ax)
      expect(described_class.ax_skills).not_to include(befoulment)
    end

    it '.befoulments returns befoulment category modifiers' do
      expect(described_class.befoulments).to include(befoulment)
      expect(described_class.befoulments).not_to include(ax)
    end
  end

  describe '#buff?' do
    it 'returns true when polarity is 1' do
      modifier = build(:weapon_stat_modifier, polarity: 1)
      expect(modifier.buff?).to be true
    end

    it 'returns false when polarity is -1' do
      modifier = build(:weapon_stat_modifier, polarity: -1)
      expect(modifier.buff?).to be false
    end
  end

  describe '#debuff?' do
    it 'returns true when polarity is -1' do
      modifier = build(:weapon_stat_modifier, polarity: -1)
      expect(modifier.debuff?).to be true
    end

    it 'returns false when polarity is 1' do
      modifier = build(:weapon_stat_modifier, polarity: 1)
      expect(modifier.debuff?).to be false
    end
  end

  describe '.find_by_game_skill_id' do
    it 'finds a modifier by game_skill_id' do
      modifier = create(:weapon_stat_modifier, game_skill_id: 42)
      expect(described_class.find_by_game_skill_id(42)).to eq(modifier)
    end

    it 'coerces string ids to integer' do
      modifier = create(:weapon_stat_modifier, game_skill_id: 42)
      expect(described_class.find_by_game_skill_id('42')).to eq(modifier)
    end

    it 'returns nil when not found' do
      expect(described_class.find_by_game_skill_id(999)).to be_nil
    end
  end
end
