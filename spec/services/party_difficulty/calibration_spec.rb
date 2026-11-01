# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PartyDifficulty::Calibration do
  before do
    DifficultyRule.delete_all
    Difficulty.delete_all
    DifficultyComponent.delete_all

    DifficultyComponent.create!(name: 'weapon', weight: 1, enabled: true, min_count_to_score: 0)
    Difficulty.with_coverage_validation_skipped do
      Difficulty.create!(slug: 'low', name: 'Low', min_score: 0, max_score: 49.99, sort_order: 0)
      Difficulty.create!(slug: 'mid', name: 'Mid', min_score: 50, max_score: 100, sort_order: 1)
    end
  end

  let!(:kept) do
    DifficultyRule.create!(name: 'Uncapped weapons', component: 'weapon', rule_type: 'weapon_uncap_at_least',
                           weight: 2.0, active: true, params: { 'min_uncap_level' => 4, 'min_count' => 1 })
  end
  let!(:unlisted) do
    DifficultyRule.create!(name: 'Old rule', component: 'weapon', rule_type: 'weapon_uncap_at_least',
                           weight: 1.0, active: true, params: { 'min_uncap_level' => 3, 'min_count' => 1 })
  end

  def ruleset(rules:, tiers: nil)
    PartyDifficulty::Calibration::Ruleset.new(
      components: [{ 'name' => 'weapon', 'weight' => 3.0, 'target_max' => 10.0, 'min_count_to_score' => 0, 'enabled' => true }],
      rules: rules,
      tiers: tiers || [
        { 'slug' => 'low', 'name' => 'Low', 'min_score' => 0.0, 'max_score' => 19.99 },
        { 'slug' => 'mid', 'name' => 'Intermediate', 'min_score' => 20.0, 'max_score' => 100.0 }
      ]
    )
  end

  let(:new_rule) do
    { 'id' => 'new-ulb', 'name' => 'ULB weapons', 'component' => 'weapon', 'rule_type' => 'weapon_uncap_at_least',
      'weight' => 4.0, 'active' => true, 'params' => { 'min_uncap_level' => 5, 'min_count' => 1 } }
  end
  let(:kept_rule) do
    PartyDifficulty::Calibration::Ruleset.rule_hash(kept).merge('name' => 'FLB weapons', 'weight' => 5.0)
  end

  describe 'Ruleset' do
    it 'gives rules without a UUID a stable one derived from the name' do
      rs = ruleset(rules: [new_rule])

      expect(rs.rule_records.first.id).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
      expect(rs.rule_id(new_rule)).to eq(ruleset(rules: [new_rule]).rule_id(new_rule))
    end

    it 'round-trips the live ruleset through its JSON form' do
      current = PartyDifficulty::Calibration::Ruleset.current
      copy = PartyDifficulty::Calibration::Ruleset.new(**current.to_h.symbolize_keys)

      expect(copy.to_h).to eq(current.to_h)
    end
  end

  describe 'Applier' do
    it 'updates rules by id, creates new ones, and deactivates rules the file leaves out' do
      PartyDifficulty::Calibration::Applier.new(ruleset(rules: [kept_rule, new_rule])).apply!

      expect(kept.reload).to have_attributes(name: 'FLB weapons', weight: 5.0, active: true)
      expect(unlisted.reload.active).to be(false)
      created = DifficultyRule.find_by!(name: 'ULB weapons')
      expect(created.id).to eq(ruleset(rules: [new_rule]).rule_id(new_rule))
    end

    it 'updates components and moves tier cutoffs together' do
      PartyDifficulty::Calibration::Applier.new(ruleset(rules: [kept_rule])).apply!

      expect(DifficultyComponent.for('weapon')).to have_attributes(weight: 3.0, target_max: 10.0)
      expect(Difficulty.find_by!(slug: 'mid')).to have_attributes(name: 'Intermediate', min_score: 20.0)
      expect(Difficulty.find_by!(slug: 'low').max_score).to eq(19.99)
    end

    it 'rejects tiers that leave a gap and changes nothing' do
      gap = [
        { 'slug' => 'low', 'name' => 'Low', 'min_score' => 0.0, 'max_score' => 19.99 },
        { 'slug' => 'mid', 'name' => 'Mid', 'min_score' => 30.0, 'max_score' => 100.0 }
      ]

      expect { PartyDifficulty::Calibration::Applier.new(ruleset(rules: [kept_rule], tiers: gap)).apply! }
        .to raise_error(ArgumentError, /coverage gap/)
      expect(kept.reload.weight).to eq(2.0)
      expect(DifficultyComponent.for('weapon').weight).to eq(1.0)
    end

    it 'applies again without changes' do
      rs = ruleset(rules: [kept_rule, new_rule])
      PartyDifficulty::Calibration::Applier.new(rs).apply!

      expect { PartyDifficulty::Calibration::Applier.new(rs).apply! }.not_to(change { DifficultyConfig.current_version })
    end
  end

  describe '#score' do
    it 'scores against the in-memory ruleset without saving it' do
      party = create(:party)
      rs = ruleset(rules: [kept_rule, new_rule])

      expect { described_class.new(rs).score(party) }.not_to(change { DifficultyRule.count })
    end
  end
end
