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

  it "returns nil for count bases needing weapon-group tags we lack (epic/militis)" do
    expect(val(EffStruct.new(scaling_kind: "per_grid_count", value: 4, count_basis: "epic"))).to be_nil
  end
end
