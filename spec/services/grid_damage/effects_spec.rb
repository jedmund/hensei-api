# frozen_string_literal: true

require "rails_helper"

RSpec.describe GridDamage::Effects do
  EffStruct = Struct.new(:scaling_kind, :boost_type, :series, :value, :condition, :count_basis, # rubocop:disable Lint/ConstantDefinitionInBlock
                         :count_cap, :per_copy_cap, :total_cap, :shared_cap_group, :modifier,
                         keyword_init: true)
  WepStruct = Struct.new(:proficiency, :granblue_id, :max_skill_level, :max_level, keyword_init: true) # rubocop:disable Lint/ConstantDefinitionInBlock

  let(:weapon) { WepStruct.new(proficiency: 1, granblue_id: "A", max_skill_level: 15, max_level: 200) }
  let(:composition) { { weapon_type_counts: { 1 => 3 }, weapon_group_count: 6, omega_skill_count: 2 } }

  def val(effect, state: {})
    described_class.value_for(effect, weapon: weapon, state: state, composition: composition)
  end

  it "static → the value" do
    expect(val(EffStruct.new(scaling_kind: "static", value: 35))).to eq(35.0)
  end

  it "conditional_flat → value when the condition is met, nil otherwise" do
    base = { scaling_kind: "conditional_flat", value: 40 }
    expect(val(EffStruct.new(**base, condition: { "type" => "weapon_group_count", "gte" => 4 }))).to eq(40.0)
    expect(val(EffStruct.new(**base, condition: { "type" => "weapon_group_count", "gte" => 8 }))).to be_nil
  end

  it "per_grid_count → value × count(basis)" do
    expect(val(EffStruct.new(scaling_kind: "per_grid_count", value: 4, count_basis: "weapon_group"))).to eq(24.0)
  end

  it "per_grid_count caps the copies at count_cap" do
    e = EffStruct.new(scaling_kind: "per_grid_count", value: 2, count_basis: "weapon_type", count_cap: 2)
    expect(val(e)).to eq(4.0) # 2 × min(3, 2)
  end

  it "foe_hp_supplemental → the per-copy cap (assumes max foe HP)" do
    expect(val(EffStruct.new(scaling_kind: "foe_hp_supplemental", per_copy_cap: 50_000))).to eq(50_000.0)
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

  it "returns nil for count bases needing weapon-group tags we lack (epic/militis)" do
    expect(val(EffStruct.new(scaling_kind: "per_grid_count", value: 4, count_basis: "epic"))).to be_nil
  end
end
