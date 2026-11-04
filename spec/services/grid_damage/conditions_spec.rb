# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GridDamage::Conditions do
  let(:weapon) { double(granblue_id: 'W1', max_skill_level: 20, max_level: 200) }
  let(:composition) do
    { distinct_weapon_type_count: 4, max_weapon_type_count: 4, skill_type_count: 15, id_counts: { 'W1' => 3 } }
  end
  let(:state) do
    { debuff_count: 5, mc_crit_rate: 100, foe_element: 'non_elemental', foe_statuses: ['Bounty'], arcarum: false }
  end

  it 'treats a blank/{} condition as always met' do
    expect(described_class.met?({})).to be(true)
    expect(described_class.met?(nil)).to be(true)
  end

  it 'evaluates canonical count-basis threshold conditions' do
    expect(described_class.met?({ 'type' => 'count_basis_gte', 'basis' => 'distinct_weapon_types', 'gte' => 4 },
                                composition: composition)).to be(true)
    expect(described_class.met?({ 'type' => 'count_basis_gte', 'basis' => 'distinct_weapon_types', 'gte' => 5 },
                                composition: composition)).to be(false)
    expect(described_class.met?({ 'type' => 'skill_type_count', 'gte' => 15 }, composition: composition)).to be(true)
  end

  it 'evaluates max_same_weapon_type for Convergence-style gates' do
    expect(described_class.met?({ 'type' => 'count_basis_gte', 'basis' => 'max_same_weapon_type', 'gte' => 4 },
                                composition: composition)).to be(true)
    expect(described_class.met?({ 'type' => 'count_basis_gte', 'basis' => 'max_same_weapon_type', 'gte' => 5 },
                                composition: composition)).to be(false)
  end

  it 'requires all ten distinct weapon types for Heroic Tale' do
    condition = { 'type' => 'count_basis_gte', 'basis' => 'distinct_weapon_types', 'gte' => 10 }

    expect(described_class.met?(condition, composition: { distinct_weapon_type_count: 9 })).to be(false)
    expect(described_class.met?(condition, composition: { distinct_weapon_type_count: 10 })).to be(true)
  end

  it "evaluates same_id_count against the bearing weapon's copies" do
    expect(described_class.met?({ 'type' => 'same_id_count', 'gte' => 3 }, composition: composition, weapon: weapon)).to be(true)
    expect(described_class.met?({ 'type' => 'same_id_count', 'gte' => 4 }, composition: composition, weapon: weapon)).to be(false)
  end

  it 'evaluates state counts (foe_debuff_count, mc_crit_rate)' do
    expect(described_class.met?({ 'type' => 'foe_debuff_count', 'gte' => 5 }, state: state)).to be(true)
    expect(described_class.met?({ 'type' => 'mc_crit_rate', 'gte' => 100 }, state: state)).to be(true)
    expect(described_class.met?({ 'type' => 'foe_debuff_count', 'gte' => 6 }, state: state)).to be(false)
  end

  it 'evaluates per-weapon level conditions' do
    expect(described_class.met?({ 'type' => 'skill_level', 'gte' => 20 }, weapon: weapon)).to be(true)
    expect(described_class.met?({ 'type' => 'weapon_level', 'gte' => 250 }, weapon: weapon)).to be(false)
  end

  it 'evaluates foe element/status' do
    expect(described_class.met?({ 'type' => 'foe_element', 'is' => 'non_elemental' }, state: state)).to be(true)
    expect(described_class.met?({ 'type' => 'foe_status', 'status' => 'Bounty' }, state: state)).to be(true)
  end

  it 'evaluates Arcarum venue conditions only when the state is explicit' do
    condition = { 'type' => 'arcarum', 'eq' => true }

    expect(described_class.met?(condition, state: { arcarum: true })).to be(true)
    expect(described_class.met?(condition, state: { arcarum: false })).to be(false)
    expect(described_class.met?(condition, state: {})).to be(false)
  end

  it 'defers boost_level when no enhancements are supplied (1st pass)' do
    expect(described_class.met?({ 'type' => 'boost_level', 'gte' => 280 })).to be(false)
  end

  it 'evaluates boost_level against the supplied per-frame enhancements (2nd pass)' do
    cond = { 'type' => 'boost_level', 'gte' => 280 }
    expect(described_class.met?(cond, state: { enhancements: { optimus: 420, omega: 20 } })).to be(true)
    expect(described_class.met?(cond, state: { enhancements: { optimus: 200, omega: 20 } })).to be(false)
  end

  it 'includes the final turn of a turn_lte condition' do
    expect(described_class.met?({ 'type' => 'turn_lte', 'lte' => 8 }, state: { turn: 8 })).to be(true)
  end

  it 'stops applying a turn_lte condition on the following turn' do
    expect(described_class.met?({ 'type' => 'turn_lte', 'lte' => 8 }, state: { turn: 9 })).to be(false)
  end

  it 'uses turn 1 when a turn_lte panel state omits the turn' do
    expect(described_class.met?({ 'type' => 'turn_lte', 'lte' => 8 }, state: {})).to be(true)
  end

  it "gates transcendence_step on the copy's transcendence" do
    condition = { 'type' => 'transcendence_step', 'gte' => 3 }

    expect(described_class.met?(condition, grid_weapon: double(transcendence_step: 3))).to be(true)
    expect(described_class.met?(condition, grid_weapon: double(transcendence_step: 2))).to be(false)
    expect(described_class.met?(condition)).to be(false).or(be_nil)
  end

  it "gates copy_skill_level on the copy's skill level" do
    condition = { 'type' => 'copy_skill_level', 'gte' => 20 }
    copy = double(skill_level: nil, uncap_level: 5, transcendence_step: 0)

    expect(described_class.met?(condition, weapon: weapon, grid_weapon: copy)).to be(true)
    expect(described_class.met?(condition, weapon: weapon, grid_weapon: double(skill_level: 15))).to be(false)
    expect(described_class.met?(condition, weapon: weapon)).to be(false).or(be_nil)
    expect(described_class.met?(condition, grid_weapon: copy)).to be(false).or(be_nil)
  end

  it "gates weapon_specialty on the MC's specialties" do
    condition = { 'type' => 'weapon_specialty' }
    staff = double(proficiency: GranblueEnums::PROFICIENCY_ENUM[:staff])

    expect(described_class.met?(condition, weapon: staff, composition: { mc_specialties: %w[sabre staff] })).to be(true)
    expect(described_class.met?(condition, weapon: staff, composition: { mc_specialties: %w[sabre] })).to be(false)
    expect(described_class.met?(condition, weapon: staff)).to be(false)
    expect(described_class.met?(condition, composition: { mc_specialties: %w[sabre] })).to be(false)
  end

  it 'requires every equipped weapon to be different for all_weapons_unique' do
    condition = { 'type' => 'all_weapons_unique' }

    expect(described_class.met?(condition, composition: { id_counts: { 'W1' => 1, 'W2' => 1 } })).to be(true)
    expect(described_class.met?(condition, composition: composition)).to be(false)
    expect(described_class.met?(condition, composition: { id_counts: {} })).to be(false)
    expect(described_class.met?(condition)).to be(false)
  end

  it 'treats unknown and invalid count conditions as not met' do
    expect(described_class.met?({ 'type' => 'mystery', 'gte' => 1 }, state: state, composition: composition)).to be(false)
    expect(described_class.met?({ 'type' => 'count_basis_gte', 'basis' => 'weapon_type', 'gte' => 1 },
                                composition: composition)).to be(false)
    expect(described_class.met?({ 'type' => 'count_basis_gte', 'basis' => 'distinct_weapon_types', 'gte' => 0 },
                                composition: composition)).to be(false)
  end

  it 'treats a missing weapon as zero for per-weapon conditions' do
    expect(described_class.met?({ 'type' => 'skill_level', 'gte' => 1 })).to be(false)
    expect(described_class.met?({ 'type' => 'weapon_level', 'gte' => 0 })).to be(true)
    expect(described_class.met?({ 'type' => 'same_id_count', 'gte' => 1 }, composition: composition)).to be(false)
    expect(described_class.met?({ 'type' => 'skill_type_count', 'gte' => 16 }, composition: composition)).to be(false)
  end

  it 'matches the foe element and status exactly' do
    expect(described_class.met?({ 'type' => 'foe_element', 'is' => 'fire' }, state: state)).to be(false)
    expect(described_class.met?({ 'type' => 'foe_element', 'is' => nil })).to be(true)
    expect(described_class.met?({ 'type' => 'foe_status', 'status' => 'Glaciate' }, state: state)).to be(false)
    expect(described_class.met?({ 'type' => 'arcarum', 'eq' => false }, state: state)).to be(true)
  end

  it 'reads boost_level from the highest of the optimus, omega and taboo enhancements' do
    cond = { 'type' => 'boost_level', 'gte' => 150 }

    expect(described_class.met?(cond, state: { enhancements: { taboo: 150, optimus: nil } })).to be(true)
    expect(described_class.met?(cond, state: { enhancements: { omega: '149.5' } })).to be(false)
  end

  it 'leaves critical_capped to the panel and flags it as crit-gated' do
    condition = { 'type' => 'critical_capped' }

    expect(described_class.met?(condition)).to be(true)
    expect(described_class.crit_gated?(condition)).to be(true)
    expect(described_class.crit_gated?({ 'type' => 'mc_crit_rate', 'gte' => 100 })).to be(false)
    expect(described_class.crit_gated?(nil)).to be(false)
  end
end
