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

  it "doesn't read a proc's damage ceiling as a DMG Cap boost (Magician-Tower's Calamity)" do
    r = parse("Massive boost to Earth allies' {{tt|ATK|'''Modifier:''' EX}}.<br />" \
              "MC deals 300% Earth damage to all foes every 3 turns (Damage cap: ~400,000).")
    expect(boost(r, "dmg_cap")).to be_nil
    expect(boost(r, "atk")).to be_present
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
  describe "proc and condition text (2026-10 audit)" do
    def boost_types(desc) = parse(desc)[:clauses].map { |c| c[:boost_type] }

    it "splits a sentence ending in an all-caps stat and skips its heal proc (Empress-Justice's Virtue)" do
      r = parse("When main weapon: Massive boost to Water allies' {{tt|ATK|'''Modifier:''' EX}}. Water allies restore " \
                "10% HP upon casting [[Dispel|buff-removing skills]] (Healing cap: 3000).")
      expect(r[:clauses].map { |c| [c[:boost_type], c[:value]] }).to eq([["atk", nil]])
    end

    it "skips chance-based heal procs (Sauna-Goer's Companion)" do
      expect(boost_types("When main weapon (MC only): ~30% chance to restore HP (Healing cap: 1000) and remove " \
                         "1 debuff upon normal attacks.")).to be_empty
    end

    it "never reads an HP threshold as an HP boost or a value (Impervious Covenant)" do
      r = parse("[[#Impervious Covenant|Supplemental damage]] to spear- and katana-specialty allies' attacks when HP " \
                "is above 80% (Damage cap: 30,000)")
      expect(boost(r, "hp")).to be_nil
      expect(r[:clauses].filter_map { |c| c[:value] }).to be_empty
    end

    it "ignores HP costs and per-HP counts (Rikishi's Pride, Whispers of Death)" do
      expect(boost_types("'''When main weapon (MC only):'''<br />Increase {{ClassSkill|In the Face of Adversity}}'s " \
                         "specs.<br />(Gain {{status|Bonus DMG|a=50%|t=3t}} and {{status|Guts|t=i|n=1}}.<br />" \
                         "Consumes 40% of max HP instead.)")).not_to include("hp")
      expect(boost_types("Boost {{ClassSkill|skill=Splitting Spirit}} to 3% charge bar per 200 HP.")).to be_empty
    end

    it "reads 'N% of the foe's max HP' as neither HP nor a value (Golden Advent II)" do
      r = parse("'''When main weapon (MC only):''' {{tt|Guaranteed|Unaffected by ''Hit to triple attack rate'' " \
                "debuffs}} triple attacks against foes in Break. Supplemental damage dealt equal to 2% of the foe's " \
                "Max HP (Damage cap: 100,000) to foes in Break.")
      expect(boost(r, "hp")).to be_nil
      expect(r[:clauses].filter_map { |c| c[:value] }).to be_empty
    end

    it "skips boosts that only apply against foes in a state (Golden Advent, Astral Thrust)" do
      expect(boost_types("'''When main weapon (MC only):''' 75% boost to double attack rate and 30% boost to triple " \
                         "attack rate against foes in Break.")).to be_empty
      expect(boost_types("10% boost to Water allies' one-foe attack damage cap against foes with 5 or more " \
                         "debuffs.")).to be_empty
    end

    it "skips boosts that need a status on the MC or foe" do
      [
        "When main weapon (MC only): ~10% bonus Light damage effect when foe has {{tt|Charmed|{{status|Charmed}}}} effect.",
        "When main weapon (MC only): 15% [[Bonus_Damage|Bonus Dark DMG]] effect when under {{status|Cursed}}.",
        "'''When main weapon (MC only):''' 55% boost to double attack rate and 30% boost to triple attack rate " \
        "while [[Superstar|High Voltage]] is in effect.",
        "When main weapon (MC only): 10% bonus Water DMG effect when double attack rate is boosted."
      ].each { |desc| expect(boost_types(desc)).to be_empty, desc }
    end

    it "keeps 'when MC is not debuffed' boosts, which the panel shows (Sunveil's Crown, PWwPYz)" do
      r = parse("'''When main weapon (MC only):'''<br />50% boost to skill damage and 30% boost to skill damage cap " \
                "for Light allies when MC is not debuffed.")
      expect(boost(r, "skill_dmg")).to include(value: 50.0)
      expect(boost(r, "skill_dmg_cap")).to include(value: 30.0)
    end

    it "keeps elemental amplify against an element's foes" do
      expect(boost_types("Amplify damage against Light foes by 10%.")).to include("elem_amplify")
    end

    it "skips on-action procs (Ogre's Retribution, Shell-Piercing)" do
      expect(boost_types("'''When main weapon (MC only):'''<br />200% full-force counter upon taking damage " \
                         "(3 hits).<br />500% Light damage to a foe upon countering (Damage cap: ~560,000).")).to be_empty
      expect(boost_types("When main weapon (MC only): 50% chance to inflict {{status|DEF Lowered (Stackable)|a=10%|" \
                         "am=30%|t=180s}} with every normal attack.")).to be_empty
    end

    it "treats 'From a …:' as an event trigger (Heavenrend Spearpoint II)" do
      r = parse("'''When main weapon:'''<br />'''From a Wind ally's 2nd attack of a Double Strike or higher " \
                "effect:'''<br />Supplement normal attack damage by 50,000.")
      expect(r[:clauses]).to be_empty
    end

    it "doesn't read a critical hit damage cap as Critical (One Sting, One Kill II)" do
      r = parse("'''When main weapon (MC only):''' Every superior elemental attack will be a critical " \
                "hit.<br />20% boost to all allies' critical hit damage cap.")
      valued = r[:clauses].select { |c| c[:value] || c[:size] }.map { |c| c[:boost_type] }
      expect(valued).not_to include("critical", "dmg_cap")
    end
  end
end
