# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::CharacterSkills::EffectParser do
  let(:veil) { instance_double('Status', game_status_id: nil, variant_kind: nil, id: 'veil-id', category: 'buff') }
  let(:jammed) { instance_double('Status', game_status_id: nil, variant_kind: nil, id: 'jammed-id', category: 'debuff') }
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
    let(:charge_boost) { instance_double('Status', game_status_id: nil, variant_kind: nil, id: 'cb-id', category: 'buff') }
    let(:paradise) { instance_double('Status', game_status_id: nil, variant_kind: nil, id: 'field-id', category: 'field') }
    let(:mystery) { instance_double('Status', game_status_id: nil, variant_kind: nil, id: 'mystery-id', category: 'special') }
    let(:lookup) do
      { by_name: { 'veil' => veil, 'jammed' => jammed, 'charge boost' => charge_boost, 'paradise' => paradise,
                   'mystery' => mystery }, by_id: {} }
    end

    it "grants a buff even when the previous clause says 'to a foe'" do
      # The 80-character text window reaches back into the damage line.
      effect = parser.parse("400% Fire damage to a foe.\nGain {{status|Charge Boost|t=3T}}.").find { |e| e[:status_id] == 'cb-id' }
      expect(effect).to include(effect_type: 'grant_status', target: 'caster')
    end

    it "follows the effect's own verb over the status's usual category (D36)" do
      expect(parser.parse('Gain {{status|Jammed}}.').first).to include(effect_type: 'grant_status', category: 'buff')
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

  describe 'status variants (D31)' do
    let(:def_down) { instance_double('Status', id: 'dd', category: 'debuff', game_status_id: '1020', variant_kind: 'turns') }
    let(:crest) { instance_double('Status', id: 'crest', category: 'buff', game_status_id: '6528', variant_kind: 'level') }
    let(:other_self) { instance_double('Status', id: 'os', category: 'buff', game_status_id: '1405', variant_kind: 'uses') }
    let(:lookup) { { by_name: { 'def down' => def_down, 'deluge crest' => crest, 'other self' => other_self }, by_id: {} } }

    before { allow(Granblue::Parsers::StatusName).to receive(:exceptions).and_return(Set.new) }

    it "resolves a numbered name to its status and keeps the number as the effect's variant" do
      effect = parser.parse('Inflict {{status|DEF Down 4|t=4T}} on a foe.',
                            game_details: [{ id: '1020_14', category: 'debuff' }, { id: '1010', category: 'debuff' }]).first
      expect(effect).to include(status_id: 'dd', status_variant: 4, status_variant_kind: 'turns',
                                game_status_id: '1020_14', duration_value: 4)
    end

    it "takes the kind from n= or the status's family when t= doesn't match" do
      uses = parser.parse('Gain {{status|Other Self 1|n=1}}.').first
      level = parser.parse('Gain {{status|Deluge Crest 3}}.').first
      expect([uses[:status_variant_kind], level[:status_variant_kind]]).to eq(%w[uses level])
    end

    it 'records no exact id when the skill lists two variants of the base' do
      effect = parser.parse('Inflict {{status|DEF Down 2}}.',
                            game_details: [{ id: '1020_12', category: 'debuff' }, { id: '1020_13', category: 'debuff' }]).first
      expect(effect).not_to have_key(:game_status_id)
    end

    it 'leaves an unnumbered status without a variant' do
      effect = parser.parse('Inflict {{status|DEF Down|t=180s}}.', game_details: [{ id: '1020', category: 'debuff' }]).first
      expect(effect).to include(game_status_id: '1020')
      expect(effect.keys).not_to include(:status_variant, :status_variant_kind)
    end
  end

  describe 'instant effects (category special)' do
    let(:charge) { instance_double('Status', id: 'cb', category: 'special', game_status_id: '1061', variant_kind: nil) }
    let(:delay) { instance_double('Status', id: 'dl', category: 'special', game_status_id: '1040', variant_kind: nil) }
    let(:lookup) { { by_name: { 'charge boost' => charge, 'delay' => delay }, by_id: {} } }

    it "types each by its own mention's verb, not the previous clause" do
      effects = parser.parse("Big damage to a foe.\nAll allies gain {{status|Charge Boost|a=10%}}.\nInflict {{status|Delay}}.")
      expect(effects.map { |e| [e[:status_id], e[:effect_type]] }).to eq([%w[cb grant_status], %w[dl inflict_status]])
    end
  end

  describe 'per-effect category (D36)' do
    let(:hostility) { instance_double('Status', id: 'h', category: 'buff', game_status_id: '1463', variant_kind: nil) }
    let(:lookup) { { by_name: { 'hostility boosted' => hostility }, by_id: {} } }

    it "takes the game's array for the status in this skill" do
      effect = parser.parse('Gain {{status|Hostility Boosted}}.', game_details: [{ id: '1463', category: 'debuff' }]).first
      expect(effect).to include(category: 'debuff', effect_type: 'inflict_status')
    end

    it "makes a self-inflicted status a debuff on the caster, whatever the clause's subject" do
      effect = parser.parse('Big damage to a foe. Self-inflict {{status|Hostility Boosted}}.').first
      expect(effect).to include(category: 'debuff', effect_type: 'inflict_status', target: 'caster')
    end

    it "falls back to the status's usual category without game data or a verb" do
      effect = parser.parse("('''While {{status|Hostility Boosted}} is in effect:''' …)").first
      expect(effect).to include(category: 'buff', effect_type: 'grant_status')
    end
  end

  describe 'curated categories (D37)' do
    let(:bon_vivant) { instance_double('Status', id: 'bv', category: 'buff', game_status_id: '7001', variant_kind: nil) }
    let(:lookup) { { by_name: { 'bon vivant' => bon_vivant }, by_id: {} } }

    before do
      allow(Granblue::Parsers::CuratedStatusCategories).to receive(:load)
        .and_return('bon vivant' => { category: 'buff', game_status_id: nil })
    end

    it "overrides the effect's verb: a self-inflicted curated buff is a buff on the caster" do
      effect = parser.parse('Big damage to a foe. Self-inflict {{status|Bon Vivant}}.').first
      expect(effect).to include(category: 'buff', effect_type: 'grant_status', target: 'caster')
    end

    it "never overrides the game's array for the status in this skill" do
      effect = parser.parse('Self-inflict {{status|Bon Vivant}}.', game_details: [{ id: '7001', category: 'debuff' }]).first
      expect(effect).to include(category: 'debuff', effect_type: 'inflict_status')
    end
  end
end
