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
    # "100% hit to multiattack rate" ≈ −100% DA (guaranteed-multiattack penalty)
    expect(boost(r, "da")).to include(value: -100.0)
  end

  it "routes single-attack bonus DMG off the elemental Bonus DMG line (Hraesvelgr Einar)" do
    r = parse("When main weapon: 80% Bonus Water DMG effect to Water allies' single attacks.")
    expect(r[:main_hand_only]).to be(true)
    # Single-attack-only bonus is its own mechanic — NOT on the panel's Bonus DMG line
    # (5JPIJg panel: Bonus Water DMG 46.8 = Deathstrike only, Einar's 80 absent).
    expect(boost(r, "bonus_elem_dmg")).to be_nil
    expect(boost(r, "bonus_elem_dmg_single")).to include(value: 80.0)
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

  it "gates every Heroic Tale boost on all ten weapon types" do
    result = parse("Boost to ATK and damage cap when all weapon groups are equipped", name: "Heroic Tale")
    condition = { "type" => "count_basis_gte", "basis" => "distinct_weapon_types", "gte" => 10 }

    expect(boost(result, "atk")).to include(value: nil, condition: condition)
    expect(boost(result, "dmg_cap")).to include(value: nil, condition: condition)
  end

  it "frames a plain elemental boost (no aura-word) as EX, not normal" do
    r = parse("Big boost to wind allies' ATK")
    atk = boost(r, "atk")
    expect(atk).to include(size: "big", value: nil, series: "ex")
  end

  it "still frames an aura-word skill by its aura (Inferno's = normal)" do
    r = parse("Big boost to fire allies' ATK", name: "Inferno's Might")
    expect(boost(r, "atk")[:series]).to eq("normal")
  end

  it "frames non-core auras (Ultima, Militis) as EX (unboostable)" do
    expect(parse("Boost to fire allies' C.A. DMG cap", name: "Arsus Excelsior")[:clauses].first[:series]).to eq("ex")
    expect(parse("Supplement light allies' C.A. DMG", name: "Glimmer's Crux")[:clauses].first[:series]).to eq("ex")
  end

  it "frames a bare aura-boostable modifier (no aura prefix) as normal" do
    r = parse("Big boost to wind allies' ATK and 10% cut to wind allies' max HP", name: "Tyranny")
    expect(boost(r, "atk")[:series]).to eq("normal")
  end

  it "derives omega series from an aura-word in the name" do
    r = parse("Big boost to fire allies' ATK", name: "Ironflame's Might")
    expect(boost(r, "atk")[:series]).to eq("omega")
  end

  it "maps an enmity skill to the enmity boost_type (not atk+hp from the condition phrase)" do
    r = parse("Boost to ATK based on how low HP is (MC only).")
    expect(r[:mc_only]).to be(true)
    expect(boost(r, "enmity")).to include(formula_type: "enmity")
    expect(boost(r, "atk")).to be_nil
    expect(boost(r, "hp")).to be_nil
  end

  it "maps a progression skill to e_atk_prog" do
    r = parse("Medium boost to wind allies' ATK based on number of turns passed")
    expect(boost(r, "e_atk_prog")).to include(formula_type: "progression", size: "medium")
  end

  it "derives ex series from a leading EX aura-word (Amber Arts)" do
    r = parse("Boost to fire allies' C.A. DMG and C.A. DMG cap", name: "Amber Arts")
    expect(r[:clauses].first[:series]).to eq("ex")
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

  it "skips event-triggered battle effects — proc text is not a passive boost (Flame of the Godrender)" do
    r = parse("'''When main weapon (MC only):'''<br />'''When MC's HP is 50% or above after normal attacks:''' " \
              "<br /> 6-hit, 100% Fire damage to a foe (Damage cap: ~140,000 per hit). <br /> Raise foe's Singed lvl by 1.")
    expect(r[:clauses]).to be_empty
    expect(r[:skip]).to eq("triggered_effect")
  end

  it "skips end-of-turn procs (Prayer of the Phoenix)" do
    r = parse("When main weapon (MC only): At end of turn when a foe's Singed lvl is 7 or above: " \
              "Restore 10% of Fire allies' HP (Healing cap: 500). All Fire allies gain Charge Bar 10%.")
    expect(r[:clauses]).to be_empty
    expect(r[:skip]).to eq("triggered_effect")
  end

  it "still parses grid-state conditions as passives (Enforcement ≥280)" do
    r = parse("When any of Fire Omega, Fire Taboo, or Fire Optimus weapon skills have a boost of 280% or above: " \
              "/ 20% ATK boost to Fire allies' ATK and 15% boost to Fire allies' DEF.")
    expect(boost(r, "atk")).to include(value: 20.0)
    expect(boost(r, "def")).to include(value: 15.0)
  end

  it "splits sentences and negates 'hit to' demerits (Gugalanna)" do
    r = parse("'''When main weapon:'''<br />Amplify Dark allies' normal attack damage by 30%. " \
              "200% hit to Dark allies' charge bar gain.")
    expect(boost(r, "na_amp")).to include(value: 30.0)
    expect(boost(r, "charge_gain")).to include(value: -200.0)
  end

  it "negates a cap demerit (Disease Demon)" do
    r = parse("'''When main weapon:'''<br />20% boost to Dark allies' normal attack damage cap. " \
              "40% hit to Dark allies' skill damage cap.")
    expect(boost(r, "na_dmg_cap")).to include(value: 20.0)
    expect(boost(r, "skill_dmg_cap")).to include(value: -40.0)
  end

  it "never reads a value out of a parenthetical aside (Athos ≥280 condition)" do
    r = parse("Boost to dark allies' multiattack rate / Amplify normal attack DMG (Boost to specs " \
              "when either dark Omega or dark Optimus weapon skills have a boost of 280% or above)")
    expect(boost(r, "na_amp")).to include(value: nil)
  end

  it "does not split sentences after abbreviation dots (C.A. DMG)" do
    r = parse("20% boost to Water allies' C.A. DMG.")
    expect(boost(r, "ca_dmg")).to include(value: 20.0)
  end
end
