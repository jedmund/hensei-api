# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PartyDifficulty::Calculator do
  let(:components) do
    [
      DifficultyComponent.new(name: 'weapon', weight: 1.0, enabled: true, min_count_to_score: 5),
      DifficultyComponent.new(name: 'character', weight: 1.0, enabled: true, min_count_to_score: 3),
      DifficultyComponent.new(name: 'summon', weight: 1.0, enabled: true, min_count_to_score: 2),
      DifficultyComponent.new(name: 'job', weight: 1.0, enabled: true, min_count_to_score: 0),
      DifficultyComponent.new(name: 'accessory', weight: 1.0, enabled: true, min_count_to_score: 0)
    ]
  end

  let(:difficulties) do
    [
      Difficulty.new(name: 'Casual', slug: 'casual', min_score: 0, max_score: 24.99, sort_order: 0),
      Difficulty.new(name: 'Mid', slug: 'mid', min_score: 25, max_score: 49.99, sort_order: 1),
      Difficulty.new(name: 'Endgame', slug: 'endgame', min_score: 50, max_score: 100, sort_order: 2)
    ]
  end

  describe '#scoreable?' do
    it 'returns false when below the weapons threshold' do
      party = build_stubbed(:party, weapons_count: 4, characters_count: 5, summons_count: 5)
      result = described_class.new(party, rules: [], components: components, difficulties: difficulties, ruleset_version: 1).call
      expect(result.scoreable).to be(false)
    end

    it 'returns true when all primary thresholds are met' do
      party = build_stubbed(:party, weapons_count: 5, characters_count: 3, summons_count: 2)
      allow(party).to receive_messages(weapons: [], characters: [], summons: [], job_id: nil, accessory_id: nil)
      result = described_class.new(party, rules: [], components: components, difficulties: difficulties, ruleset_version: 1).call
      expect(result.scoreable).to be(true)
    end
  end

  describe '#call with no rules' do
    it 'returns score 0 and the lowest tier' do
      party = build_stubbed(:party, weapons_count: 5, characters_count: 3, summons_count: 2)
      allow(party).to receive_messages(weapons: [], characters: [], summons: [], job_id: nil, accessory_id: nil)
      result = described_class.new(party, rules: [], components: components, difficulties: difficulties, ruleset_version: 1).call
      expect(result.scoreable).to be(true)
      expect(result.score).to eq(0)
      expect(result.difficulty.slug).to eq('casual')
    end
  end

  describe '#call with a single firing rule' do
    it 'normalises the contribution within its component and renormalises across present components' do
      rule = DifficultyRule.new(name: 'always', component: 'weapon', rule_type: 'weapon_uncap_at_least',
                                weight: 1.0, active: true, params: { 'min_uncap_level' => 0, 'min_count' => 1 })
      impl = instance_double(PartyDifficulty::Rules::WeaponUncapAtLeast, matching_count: 1, min_count: 1)
      allow(rule).to receive(:implementation).and_return(impl)

      party = build_stubbed(:party, weapons_count: 5, characters_count: 3, summons_count: 2)
      allow(party).to receive_messages(weapons: [], characters: [], summons: [], job_id: nil, accessory_id: nil)

      result = described_class.new(party, rules: [rule], components: components, difficulties: difficulties, ruleset_version: 1).call

      # weapon raw = 1/1 = 1.0; weighted = 1.0; characters/summons present but have no rules and skip.
      # composite = 1.0 / 1.0 * 100 = 100
      expect(result.score).to eq(100)
      expect(result.difficulty.slug).to eq('endgame')
    end
  end
end
