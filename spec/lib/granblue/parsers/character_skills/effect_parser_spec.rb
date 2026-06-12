# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::CharacterSkills::EffectParser do
  let(:veil) { instance_double('Status', id: 'veil-id', category: 'buff') }
  let(:jammed) { instance_double('Status', id: 'jammed-id', category: 'debuff') }
  let(:lookup) { { by_name: { 'veil' => veil, 'jammed' => jammed }, by_id: {} } }

  subject(:parser) { described_class.new(lookup) }

  it 'grants a known buff to the clause subject' do
    effects = parser.parse('All allies gain {{status|Veil|t=i}}.')
    expect(effects).to contain_exactly(
      hash_including(effect_type: 'grant_status', target: 'all_allies', status_id: 'veil-id', duration_unit: 'indefinite')
    )
  end

  it 'classifies a debuff as inflict on a foe with amount/accuracy/duration' do
    effect = parser.parse('Inflict {{status|Jammed|a=30%|t=3T|acc=90%}} on a foe.').first
    expect(effect).to include(
      effect_type: 'inflict_status', target: 'one_foe', amount: '30%', accuracy: '90%',
      duration_value: 3, duration_unit: 'turns'
    )
  end

  it 'parses damage with hit count and cap' do
    damage = parser.parse('5-hit, {{tt|100%|Massive}} damage to a foe (Damage cap: ~110,000).')
                   .find { |e| e[:effect_type] == 'deal_damage' }
    expect(damage).to include(target: 'one_foe', hit_count: 5, damage_cap: 110_000)
    expect(damage[:damage_pct]).to eq(100)
  end

  it 'defaults a subjectless grant to the caster' do
    expect(parser.parse('{{status|Veil}}.').first[:target]).to eq('caster')
  end

  it 'accumulates unmatched status names' do
    parser.parse('Gain {{status|Unknown Buff}}.')
    expect(parser.unmatched_statuses).to include('Unknown Buff')
  end
end
