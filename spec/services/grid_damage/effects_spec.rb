# frozen_string_literal: true

require "rails_helper"

RSpec.describe GridDamage::Effects do
  EffStruct = Struct.new(:scaling_kind, :boost_type, :series, :value, :condition, :count_basis, # rubocop:disable Lint/ConstantDefinitionInBlock
                         :count_cap, :per_copy_cap, :total_cap, :shared_cap_group, :modifier,
                         :cap_formula,
                         keyword_init: true)
  WepStruct = Struct.new(:proficiency, :granblue_id, :max_skill_level, :max_level, keyword_init: true) # rubocop:disable Lint/ConstantDefinitionInBlock
  GridStruct = Struct.new(:skill_level, :uncap_level, :transcendence_step, keyword_init: true) # rubocop:disable Lint/ConstantDefinitionInBlock

  let(:weapon) { WepStruct.new(proficiency: 1, granblue_id: "A", max_skill_level: 15, max_level: 200) }
  let(:composition) do
    { weapon_type_counts: { 1 => 3 }, weapon_series_counts: { "epic" => 2, "militis" => 4 },
      distinct_weapon_type_count: 6, omega_skill_count: 2 }
  end

  def val(effect, state: {}, grid_weapon: nil)
    described_class.value_for(effect, weapon: weapon, state: state, composition: composition,
                                      grid_weapon: grid_weapon)
  end

  it "static → the value" do
    expect(val(EffStruct.new(scaling_kind: "static", value: 35))).to eq(35.0)
  end

  it "weapon_skill_curve reuses the canonical SL and turn scaling" do
    create(:weapon_skill_datum, modifier: "Progression", boost_type: "e_atk_prog",
                                series: "normal_omega", size: "big", formula_type: "progression",
                                sl1: 0.55, sl10: 1, sl15: 1.2, sl20: 1.5, max_value: 15)
    effect = EffStruct.new(
      scaling_kind: "weapon_skill_curve", boost_type: "e_atk_prog",
      condition: { "curve" => { "modifier" => "Progression", "series" => "normal", "size" => "big" } }
    )
    grid_weapon = GridStruct.new(skill_level: 20, uncap_level: 5, transcendence_step: 0)

    expect(val(effect, state: { turn: 5 }, grid_weapon: grid_weapon)).to eq(7.5)
    expect(val(effect, state: { turn: 20 }, grid_weapon: grid_weapon)).to eq(15.0)
  end

  it "weapon_skill_curve passes HP through to canonical Enmity scaling" do
    create(:weapon_skill_datum, modifier: "Enmity", boost_type: "enmity",
                                series: "normal_omega", size: "big", formula_type: "enmity",
                                sl1: 0.83, sl10: 10, sl15: 12.5, sl20: 13.5)
    effect = EffStruct.new(
      scaling_kind: "weapon_skill_curve", boost_type: "enmity",
      condition: { "curve" => { "modifier" => "Enmity", "series" => "normal", "size" => "big" } }
    )
    grid_weapon = GridStruct.new(skill_level: 20, uncap_level: 5, transcendence_step: 0)

    expect(val(effect, state: { hp_percent: 100 }, grid_weapon: grid_weapon)).to eq(0.0)
    expect(val(effect, state: { hp_percent: 0 }, grid_weapon: grid_weapon)).to eq(40.5)
  end

  it "conditional_flat → value when the condition is met, nil otherwise" do
    base = { scaling_kind: "conditional_flat", value: 40 }
    met = { "type" => "count_basis_gte", "basis" => "distinct_weapon_types", "gte" => 4 }
    unmet = { "type" => "count_basis_gte", "basis" => "distinct_weapon_types", "gte" => 8 }
    expect(val(EffStruct.new(**base, condition: met))).to eq(40.0)
    expect(val(EffStruct.new(**base, condition: unmet))).to be_nil
  end

  it "per_grid_count → value × count(basis)" do
    expect(val(EffStruct.new(scaling_kind: "per_grid_count", value: 4, count_basis: "distinct_weapon_types"))).to eq(24.0)
  end

  it "per_grid_count caps the copies at count_cap" do
    e = EffStruct.new(scaling_kind: "per_grid_count", value: 2, count_basis: "same_weapon_type", count_cap: 2)
    expect(val(e)).to eq(4.0) # 2 × min(3, 2)
  end

  it "supplemental_cap → the per-copy cap when raw damage reaches cap" do
    expect(val(EffStruct.new(scaling_kind: "supplemental_cap", per_copy_cap: 50_000))).to eq(50_000.0)
  end

  it "supplemental_cap evaluates missing-HP cap formulas" do
    effect = EffStruct.new(
      scaling_kind: "supplemental_cap",
      cap_formula: "50000*((maxhp-curhp)/maxhp)+10000"
    )

    expect(val(effect, state: { hp_percent: 100 })).to eq(10_000.0)
    expect(val(effect, state: { hp_percent: 75 })).to eq(22_500.0)
    expect(val(effect, state: { hp_percent: 50 })).to eq(35_000.0)
    expect(val(effect, state: { hp_percent: 25 })).to eq(47_500.0)
    expect(val(effect, state: { hp_percent: 1 })).to eq(60_000.0)
  end

  it "supplemental_cap evaluates Marvel's ally-HP cap anchors" do
    effect = EffStruct.new(
      scaling_kind: "supplemental_cap",
      cap_formula: "100000*((maxhp-curhp)/maxhp)+50000"
    )

    expect(val(effect, state: { hp_percent: 100 })).to eq(50_000.0)
    expect(val(effect, state: { hp_percent: 75 })).to eq(75_000.0)
    expect(val(effect, state: { hp_percent: 50 })).to eq(100_000.0)
    expect(val(effect, state: { hp_percent: 25 })).to eq(125_000.0)
    expect(val(effect, state: { hp_percent: 1 })).to eq(150_000.0)
  end

  it "supplemental_cap evaluates current-HP cap formulas" do
    effect = EffStruct.new(
      scaling_kind: "supplemental_cap",
      cap_formula: "500000*(curhp/maxhp)+100000"
    )

    expect(val(effect, state: { hp_percent: 100 })).to eq(600_000.0)
    expect(val(effect, state: { hp_percent: 50 })).to eq(350_000.0)
    expect(val(effect, state: { hp_percent: 1 })).to eq(100_000.0)
  end

  it "hp_current_linear scales floor to cap with current HP and treats 1 as the endpoint" do
    effect = EffStruct.new(scaling_kind: "hp_current_linear", value: 5.0, total_cap: 20.0)

    expect(val(effect, state: { hp_percent: 100 })).to eq(20.0)
    expect(val(effect, state: { hp_percent: 75 })).to eq(16.25)
    expect(val(effect, state: { hp_percent: 50 })).to eq(12.5)
    expect(val(effect, state: { hp_percent: 25 })).to eq(8.75)
    expect(val(effect, state: { hp_percent: 1 })).to eq(5.0)
  end

  it "hp_missing_linear scales floor to cap with missing HP and treats 1 as the endpoint" do
    effect = EffStruct.new(scaling_kind: "hp_missing_linear", value: 5.0, total_cap: 35.0)

    expect(val(effect, state: { hp_percent: 100 })).to eq(5.0)
    expect(val(effect, state: { hp_percent: 75 })).to eq(12.5)
    expect(val(effect, state: { hp_percent: 50 })).to eq(20.0)
    expect(val(effect, state: { hp_percent: 25 })).to eq(27.5)
    expect(val(effect, state: { hp_percent: 1 })).to eq(35.0)
  end

  it "ally_max_hp_scaled scales by explicit ally max HP and applies the per-copy cap" do
    effect = EffStruct.new(scaling_kind: "ally_max_hp_scaled", value: 0.045, per_copy_cap: 40.0)

    expect(val(effect)).to be_nil
    expect(val(effect, state: { ally_max_hp: 25_425 })).to be_within(1e-9).of(11.44125)
    expect(val(effect, state: { ally_max_hp: 100_000 })).to eq(40.0)
  end

  it "per_grid_count can count weapon series such as epic and militis" do
    expect(val(EffStruct.new(scaling_kind: "per_grid_count", value: 4, count_basis: "series:epic"))).to eq(8.0)
    expect(val(EffStruct.new(scaling_kind: "per_grid_count", value: 23, count_basis: "series:militis",
                             per_copy_cap: 46))).to eq(46.0)
  end

  it "rejects legacy count_basis values" do
    effect = EffStruct.new(scaling_kind: "per_grid_count", value: 4, count_basis: "weapon_type")

    expect { val(effect) }.to raise_error(ArgumentError, /Unknown count_basis/)
  end
end
