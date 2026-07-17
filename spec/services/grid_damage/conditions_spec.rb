# frozen_string_literal: true

require "rails_helper"

RSpec.describe GridDamage::Conditions do
  let(:weapon) { double(granblue_id: "W1", max_skill_level: 20, max_level: 200) }
  let(:composition) do
    { distinct_weapon_type_count: 4, max_weapon_type_count: 4, skill_type_count: 15, id_counts: { "W1" => 3 } }
  end
  let(:state) do
    { debuff_count: 5, mc_crit_rate: 100, foe_element: "non_elemental", foe_statuses: ["Bounty"], arcarum: false }
  end

  it "treats a blank/{} condition as always met" do
    expect(described_class.met?({})).to be(true)
    expect(described_class.met?(nil)).to be(true)
  end

  it "evaluates canonical count-basis threshold conditions" do
    expect(described_class.met?({ "type" => "count_basis_gte", "basis" => "distinct_weapon_types", "gte" => 4 },
                                composition: composition)).to be(true)
    expect(described_class.met?({ "type" => "count_basis_gte", "basis" => "distinct_weapon_types", "gte" => 5 },
                                composition: composition)).to be(false)
    expect(described_class.met?({ "type" => "skill_type_count", "gte" => 15 }, composition: composition)).to be(true)
  end

  it "evaluates max_same_weapon_type for Convergence-style gates" do
    expect(described_class.met?({ "type" => "count_basis_gte", "basis" => "max_same_weapon_type", "gte" => 4 },
                                composition: composition)).to be(true)
    expect(described_class.met?({ "type" => "count_basis_gte", "basis" => "max_same_weapon_type", "gte" => 5 },
                                composition: composition)).to be(false)
  end

  it "requires all ten distinct weapon types for Heroic Tale" do
    condition = { "type" => "count_basis_gte", "basis" => "distinct_weapon_types", "gte" => 10 }

    expect(described_class.met?(condition, composition: { distinct_weapon_type_count: 9 })).to be(false)
    expect(described_class.met?(condition, composition: { distinct_weapon_type_count: 10 })).to be(true)
  end

  it "evaluates same_id_count against the bearing weapon's copies" do
    expect(described_class.met?({ "type" => "same_id_count", "gte" => 3 }, composition: composition, weapon: weapon)).to be(true)
    expect(described_class.met?({ "type" => "same_id_count", "gte" => 4 }, composition: composition, weapon: weapon)).to be(false)
  end

  it "evaluates state counts (foe_debuff_count, mc_crit_rate)" do
    expect(described_class.met?({ "type" => "foe_debuff_count", "gte" => 5 }, state: state)).to be(true)
    expect(described_class.met?({ "type" => "mc_crit_rate", "gte" => 100 }, state: state)).to be(true)
    expect(described_class.met?({ "type" => "foe_debuff_count", "gte" => 6 }, state: state)).to be(false)
  end

  it "evaluates per-weapon level conditions" do
    expect(described_class.met?({ "type" => "skill_level", "gte" => 20 }, weapon: weapon)).to be(true)
    expect(described_class.met?({ "type" => "weapon_level", "gte" => 250 }, weapon: weapon)).to be(false)
  end

  it "evaluates foe element/status" do
    expect(described_class.met?({ "type" => "foe_element", "is" => "non_elemental" }, state: state)).to be(true)
    expect(described_class.met?({ "type" => "foe_status", "status" => "Bounty" }, state: state)).to be(true)
  end

  it "evaluates Arcarum venue conditions only when the state is explicit" do
    condition = { "type" => "arcarum", "eq" => true }

    expect(described_class.met?(condition, state: { arcarum: true })).to be(true)
    expect(described_class.met?(condition, state: { arcarum: false })).to be(false)
    expect(described_class.met?(condition, state: {})).to be(false)
  end

  it "defers boost_level when no enhancements are supplied (1st pass)" do
    expect(described_class.met?({ "type" => "boost_level", "gte" => 280 })).to be(false)
  end

  it "evaluates boost_level against the supplied per-frame enhancements (2nd pass)" do
    cond = { "type" => "boost_level", "gte" => 280 }
    expect(described_class.met?(cond, state: { enhancements: { optimus: 420, omega: 20 } })).to be(true)
    expect(described_class.met?(cond, state: { enhancements: { optimus: 200, omega: 20 } })).to be(false)
  end
end
