# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PartyDifficulty::Calibration::Report do
  let(:grand_id) { '11111111-1111-1111-1111-111111111111' }
  let(:opus_id) { '22222222-2222-2222-2222-222222222222' }
  let(:ruleset) do
    PartyDifficulty::Calibration::Ruleset.new(
      components: [
        { 'name' => 'weapon', 'weight' => 3.0, 'target_max' => 10.0, 'min_count_to_score' => 0, 'enabled' => true },
        { 'name' => 'summon', 'weight' => 1.5, 'target_max' => nil, 'min_count_to_score' => 0, 'enabled' => true }
      ],
      rules: [
        { 'id' => grand_id, 'name' => 'Grands', 'component' => 'weapon', 'rule_type' => 'x', 'weight' => 4.0 },
        { 'id' => opus_id, 'name' => 'Opus', 'component' => 'weapon', 'rule_type' => 'x', 'weight' => 6.0 },
        { 'id' => 'new-summon', 'name' => 'Summons', 'component' => 'summon', 'rule_type' => 'x', 'weight' => 2.0 },
        { 'id' => 'old', 'name' => 'Retired', 'component' => 'summon', 'rule_type' => 'x', 'weight' => 1.0, 'active' => false }
      ],
      tiers: [
        { 'slug' => 'high', 'name' => 'Endgame', 'min_score' => 50.0, 'max_score' => 100.0 },
        { 'slug' => 'low', 'name' => 'Casual', 'min_score' => 0.0, 'max_score' => 49.99 }
      ]
    )
  end
  let(:summon_rule_id) { ruleset.rule_id(ruleset.rules[2]) }
  let(:results) do
    summon = { name: 'summon', present: true, raw_score: 0.5, contribution_sum: 1.0, max_weight: 2.0,
               fired: [{ id: summon_rule_id, weight: 1.0 }] }
    [
      result(1, 82.5, 'Endgame', 'high', breakdown(8.0, [{ id: grand_id, weight: 4.0 }, { id: "#{grand_id}-additional", weight: 2.0 },
                                                         { id: opus_id, weight: 2.0 }], summon: summon)),
      result(2, 40.0, 'Casual', 'low', breakdown(4.0, [{ id: grand_id, weight: 4.0 }]), name: 'Pipe | name'),
      result(3, 12.25, 'Casual', 'low', breakdown(0.0, [])),
      result(4, 100.0, 'Endgame', 'high', { components: [{ name: 'weapon', present: false }] }),
      result(5, 55.0, 'Endgame', 'high', breakdown(6.0, [{ id: opus_id, weight: 6.0 }]))
    ]
  end
  let(:baseline) do
    [
      result(1, 60.0, 'Endgame', 'high', {}),
      result(2, 55.0, 'Endgame', 'high', {}),
      result(3, 12.25, nil, nil, {}),
      result(4, 90.0, 'Top', 'high', {})
    ]
  end
  let(:fixtures) { Rails.root.join('spec/fixtures/party_difficulty/calibration_report') }

  def breakdown(weapon_sum, fired, summon: nil)
    weapon = { name: 'weapon', present: true, raw_score: weapon_sum / 10.0, contribution_sum: weapon_sum,
               max_weight: 10.0, fired: fired }
    components = [weapon]
    components << summon if summon
    { components: components }
  end

  def result(id, score, tier, slug, breakdown, name: "Party #{id}")
    PartyDifficulty::Calibration::PartyResult.new(party_id: id, shortcode: "S#{id}", name: name, score: score,
                                                  tier: tier, tier_slug: slug, breakdown: breakdown)
  end

  before { travel_to(Time.utc(2026, 11, 4, 12, 0, 0)) }

  it 'writes the same markdown without a baseline' do
    markdown = described_class.new(ruleset: ruleset, results: results).markdown
    expect(markdown).to eq(fixtures.join('candidate.md').read)
  end

  it 'writes the same markdown with a baseline' do
    markdown = described_class.new(ruleset: ruleset, results: results, baseline: baseline, label: 'v2').markdown
    expect(markdown).to eq(fixtures.join('with_baseline.md').read)
  end

  it 'writes the same CSV with and without a baseline' do
    expect(described_class.new(ruleset: ruleset, results: results).csv).to eq(fixtures.join('candidate.csv').read)
    expect(described_class.new(ruleset: ruleset, results: results, baseline: baseline).csv)
      .to eq(fixtures.join('with_baseline.csv').read)
  end

  it 'reports empty runs' do
    expect(described_class.new(ruleset: ruleset, results: [], baseline: []).markdown).to eq(fixtures.join('empty.md').read)
  end
end
