# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("lib/granblue/extractors/summon_aura_extractor")

RSpec.describe Granblue::Extractors::SummonAuraExtractor do
  let(:ex) { described_class.new }

  def main0(recs)
    recs.find { |r| r[:slot] == "main" && r[:uncap_level] == 0 && r[:transcendence_stage] == 0 }
  end

  def summon(fields)
    "{{Summon\n#{fields.map { |k, v| "|#{k}=#{v}" }.join("\n")}\n}}"
  end

  it "classifies an Optimus aura as a normal-frame multiplier (element implied)" do
    wt = summon("aura1" => "80% boost to Fire's, Hellfire's, and Inferno's [[Weapon Skills|weapon skills]].",
                "aura4" => "150% boost to Fire's, Hellfire's, and Inferno's [[Weapon Skills|weapon skills]].")
    recs = ex.extract(wt, granblue_id: "1", series: "optimus", element: "fire")
    expect(main0(recs)).to include(target: "normal_frame", value: 80.0, element: nil)
    expect(recs.find { |r| r[:uncap_level] == 5 }[:value]).to eq(150.0)
  end

  it "classifies a Magna aura as an omega-frame multiplier" do
    wt = summon("aura1" => "50% boost to Ironflame's [[Weapon Skills|weapon skills]].")
    expect(main0(ex.extract(wt, granblue_id: "2", series: "magna", element: "fire")))
      .to include(target: "omega_frame", value: 50.0)
  end

  it "classifies elemental ATK with its element" do
    wt = summon("aura1" => "100% boost to Light [[Damage Formula|Elemental]] ATK.")
    expect(main0(ex.extract(wt, granblue_id: "3", series: "providence", element: "light")))
      .to include(target: "elemental_atk", element: "light", value: 100.0)
  end

  it "recognizes the 'attack' wording and multiple elements" do
    wt = summon("aura1" => "40% boost to Dark and Earth Elemental attack.")
    r = main0(ex.extract(wt, granblue_id: "4", series: nil, element: "dark"))
    expect(r[:target]).to eq("elemental_atk")
    expect(r[:element]).to eq("earth,dark")
  end

  it "keeps the most grid-relevant clause in a multi-effect aura" do
    wt = summon("aura1" => "20% boost to Fire allies' HP.<br />30% boost to Fire Elemental ATK.")
    expect(main0(ex.extract(wt, granblue_id: "5", series: "providence", element: "fire")))
      .to include(target: "elemental_atk", value: 30.0, element: "fire")
  end

  it "maps tiers aura1/2/3/4 to uncap levels 0/3/4/5" do
    wt = summon("aura1" => "10% boost to Fire ATK.", "aura2" => "20% boost to Fire ATK.",
                "aura3" => "30% boost to Fire ATK.", "aura4" => "40% boost to Fire ATK.")
    recs = ex.extract(wt, granblue_id: "6", series: nil, element: "fire").select { |r| r[:slot] == "main" }
    expect(recs.map { |r| [r[:uncap_level], r[:value]] }.sort).to eq([[0, 10.0], [3, 20.0], [4, 30.0], [5, 40.0]])
  end

  it "maps aurat1..5 to transcendence stages 1..5 at uncap 5 and ignores aurat0" do
    wt = summon("aura4" => "40% boost to Fire ATK.", "aurat0" => "45% boost to Fire ATK.",
                "aurat1" => "50% boost to Fire ATK.", "aurat5" => "90% boost to Fire ATK.")
    recs = ex.extract(wt, granblue_id: "9", series: nil, element: "fire").select { |r| r[:slot] == "main" }
    expect(recs.map { |r| [r[:uncap_level], r[:transcendence_stage], r[:value]] }.sort)
      .to eq([[5, 0, 40.0], [5, 1, 50.0], [5, 5, 90.0]])
  end

  it "flags an element-less generic ATK buff as 'atk'" do
    wt = summon("aura1" => "30% boost to {{atkmod|ATK|m=p}} and 30% boost to DEF for Koku.")
    expect(main0(ex.extract(wt, granblue_id: "8", series: nil, element: nil))).to include(target: "atk")
  end

  it "produces nothing for a call-only summon (no aura fields)" do
    expect(ex.extract(summon("name" => "Shiva", "atk1" => "100"), granblue_id: "7")).to be_empty
  end

  describe "clause classification fixes (GBF-46, 47, 48, 52)" do
    def classify_main0(text, element: nil)
      main0(ex.extract(summon("aura1" => text), granblue_id: "9", series: nil, element: element))
    end

    context "with DMG caps and supplements (Bastet, GBF-46)" do
      it "reads a normal attack DMG cap plus supplement as other, not elemental ATK" do
        r = classify_main0("5% boost to light allies' normal attack DMG cap / " \
                           "Supplement normal attack DMG by up to 30,000 per hit", element: "wind")
        expect(r).to include(target: "other", element: nil)
      end

      it "reads an element's damage cap as other" do
        expect(classify_main0("5% boost to Light allies' damage cap.", element: "light")).to include(target: "other")
      end

      it "keeps elemental ATK when a C.A. DMG Cap boost follows in the same sentence" do
        r = classify_main0("'''Light allies:''' 80% boost to Light Elemental ATK, 25% boost to C.A. DMG, " \
                           "and 10% boost to C.A. DMG Cap.", element: "light")
        expect(r).to include(target: "elemental_atk", element: "light", value: 80.0)
      end

      it "keeps elemental ATK when a skill damage cap follows in the same clause (Qilin)" do
        r = classify_main0("50% boost to all Elemental ATK. 50% boost to skill damage. 25% boost to skill damage cap.")
        expect(r).to include(target: "elemental_atk", element: "all", value: 50.0)
      end
    end

    context "with the 'normal attack' wording (Ikelos, GBF-47)" do
      it "reads 'Water Normal attack' as normal_atk" do
        r = classify_main0("40% boost to Water Normal attack. Lowers Water allies' HP by 5%.", element: "water")
        expect(r).to include(target: "normal_atk", element: nil, value: 40.0)
      end

      it "still reads 'Normal ATK' as normal_atk" do
        expect(classify_main0("30% boost to Fire allies' Normal ATK.")).to include(target: "normal_atk", value: 30.0)
      end
    end

    context "with a Defense Order clause (Bahamut Unchained, GBF-48)" do
      it "keeps the unconditional value over the Defense Order one" do
        r = classify_main0("40% boost to ATK.<br />'''During Defense Order:''' 80% boost to ATK and " \
                           "20% boost to HP for all allies.", element: "dark")
        expect(r).to include(target: "elemental_atk", element: "all", value: 40.0, condition: nil)
      end

      it "keeps the elemental value for Defense Order summons with an elemental base clause" do
        r = classify_main0("40% boost to Water Elemental ATK.<br />During Defense Order, 60% boost to ATK " \
                           "and 15% boost to HP for Water allies.", element: "water")
        expect(r).to include(target: "elemental_atk", element: "water", value: 40.0)
      end
    end

    context "with ATK-ish wording that isn't a grid ATK boost (GBF-52)" do
      it "reads double/triple attack rate as multiattack" do
        expect(classify_main0("10% boost to all allies' DEF / 5% boost to double attack rate"))
          .to include(target: "multiattack", value: 5.0)
        expect(classify_main0("20% boost to double attack rate. 10% boost to triple attack rate."))
          .to include(target: "multiattack", value: 20.0)
      end

      it "keeps elemental ATK when a DA penalty follows in the same sentence (Ebisu)" do
        r = classify_main0("50% boost to Water Elemental ATK, penalty to Double Attack Rate.", element: "water")
        expect(r).to include(target: "elemental_atk", element: "water", value: 50.0)
      end

      it "reads boosts to named characters as other" do
        expect(classify_main0("10% boost to Cinderella girls' ATK.")).to include(target: "other")
        expect(classify_main0("20% boost to Gachapin's ATK.")).to include(target: "other")
        r = classify_main0("10% boost to all allies' DEF. <br /> Taste the glory of the Lumiel Order! " \
                           "(40% boost to Lumiel Order characters' ATK.)")
        expect(r).to include(target: "other")
        r = classify_main0("2 {{status|Wings of Promise|t=i}} to MC upon MC using a skill or charge attack (Max: 12).<br />" \
                           "(Boost to MC's {{atkmod|ATK|m=p}} and DEF based on number of {{status|Wings of Promise}}.)")
        expect(r).to include(target: "other")
      end

      it "reads battle-start statuses as other" do
        r = classify_main0("Yorozuya starts battle with {{status|Veil|t=i}} and {{status|ATK Up|t=5T}}.")
        expect(r).to include(target: "other")
      end

      it "keeps an element-possessive ATK boost as elemental ATK" do
        r = classify_main0("20% boost to Dark allies' Dark ATK.<br />30% boost to {{atkmod|ATK|m=p}} and " \
                           "30% boost to DEF for Koku.", element: "dark")
        expect(r).to include(target: "elemental_atk", element: "dark", value: 20.0)
      end
    end
  end
end
