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

  it "flags an element-less generic ATK buff as 'atk'" do
    wt = summon("aura1" => "20% boost to ATK.")
    expect(main0(ex.extract(wt, granblue_id: "8", series: nil, element: nil))).to include(target: "atk")
  end

  it "produces nothing for a call-only summon (no aura fields)" do
    expect(ex.extract(summon("name" => "Shiva", "atk1" => "100"), granblue_id: "7")).to be_empty
  end
end
