# frozen_string_literal: true

require "rails_helper"

RSpec.describe Granblue::Parsers::WeaponSkillDescriptionParser do
  def parse(desc, name: nil) = described_class.parse(desc, name: name)
  def boost(result, key) = result[:clauses].find { |c| c[:boost_type] == key }

  it "parses a main-weapon composite (Hraesvelgr Mikill Las)" do
    r = parse("When main weapon: Supplement Water allies' damage by 100,000, " \
              "10% boost to damage cap, and 100% hit to multiattack rate.")
    expect(r[:main_hand_only]).to be(true)
    expect(boost(r, "dmg_supp")).to include(value: 100_000.0)
    expect(boost(r, "dmg_cap")).to include(value: 10.0)
    expect(boost(r, "multiattack")).to include(value: 100.0)
  end

  it "parses a main-weapon bonus-DMG skill (Hraesvelgr Einar)" do
    r = parse("When main weapon: 80% Bonus Water DMG effect to Water allies' single attacks.")
    expect(r[:main_hand_only]).to be(true)
    expect(boost(r, "bonus_elem_dmg")).to include(value: 80.0)
  end

  it "parses NA amp from an MC-only main-weapon skill, ignoring the nuke clause (Geisa Ari)" do
    r = parse("When main weapon (MC only): No charge bar gain upon normal attacks, " \
              "amplify normal attack damage by 30%, and normal attacks deal 4-hit damage to random foes.")
    expect(r[:main_hand_only]).to be(true)
    expect(r[:mc_only]).to be(true)
    expect(boost(r, "na_amp")).to include(value: 30.0)
  end

  it "parses an explicit-% ATK/DEF main-weapon skill with EX series (Dandelion)" do
    r = parse("5% boost to male Wind allies' ATK (EX modifier) and 5% boost to female Wind allies' DEF when main weapon.")
    expect(boost(r, "atk")).to include(value: 5.0, series: "ex")
    expect(boost(r, "def")).to include(value: 5.0)
  end

  it "parses a plain size-tier ATK boost (no explicit value)" do
    r = parse("Big boost to wind allies' ATK")
    atk = boost(r, "atk")
    expect(atk).to include(size: "big", value: nil, series: "normal")
  end

  it "derives omega series from an aura-word in the name" do
    r = parse("Big boost to fire allies' ATK", name: "Ironflame's Might")
    expect(boost(r, "atk")[:series]).to eq("omega")
  end

  it "detects enmity formula and mc_only" do
    r = parse("Boost to ATK based on how low HP is (MC only).")
    expect(r[:mc_only]).to be(true)
    expect(boost(r, "atk")).to include(formula_type: "enmity")
  end

  it "prefers the specific cap over the general one (skill DMG cap)" do
    r = parse("15% boost to Dark allies' skill DMG cap.")
    expect(boost(r, "skill_dmg_cap")).to include(value: 15.0)
    expect(boost(r, "dmg_cap")).to be_nil
  end

  it "flags a key placeholder as skipped (no clauses)" do
    r = parse("A symbol of apocalyptic corruption. Empowered by a chosen pendulum.")
    expect(r[:clauses]).to be_empty
    expect(r[:skip]).to eq("key_placeholder")
  end
end
