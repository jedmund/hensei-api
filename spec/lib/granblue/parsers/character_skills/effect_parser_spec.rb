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

  describe 'effect_type' do
    let(:charge_boost) { instance_double('Status', id: 'cb-id', category: 'buff') }
    let(:paradise) { instance_double('Status', id: 'field-id', category: 'field') }
    let(:mystery) { instance_double('Status', id: 'mystery-id', category: 'special') }
    let(:lookup) do
      { by_name: { 'veil' => veil, 'jammed' => jammed, 'charge boost' => charge_boost, 'paradise' => paradise,
                   'mystery' => mystery }, by_id: {} }
    end

    it "grants a buff even when the previous clause says 'to a foe'" do
      # The 80-character text window reaches back into the damage line.
      effect = parser.parse("400% Fire damage to a foe.\nGain {{status|Charge Boost|t=3T}}.").find { |e| e[:status_id] == 'cb-id' }
      expect(effect).to include(effect_type: 'grant_status', target: 'caster')
    end

    it 'inflicts a debuff even when the text says gain' do
      expect(parser.parse('Gain {{status|Jammed}}.').first[:effect_type]).to eq('inflict_status')
    end

    it 'types a field status as a field effect' do
      expect(parser.parse('Create {{status|Paradise}} on the field.').first[:effect_type]).to eq('field_effect')
    end

    it 'falls back to the text for a status of unknown category' do
      expect(parser.parse('Inflict {{status|Mystery}} on a foe.').first[:effect_type]).to eq('inflict_status')
      expect(parser.parse('Gain {{status|Mystery}}.').first[:effect_type]).to eq('grant_status')
      expect(parser.parse('Inflict {{status|Unknown}} on a foe.').first[:effect_type]).to eq('inflict_status')
    end
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
