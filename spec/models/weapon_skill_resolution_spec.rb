# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("lib/granblue/parsers/weapon_skill_parser")

# Step #2 — the version↔data/effects resolution layer.
RSpec.describe "Weapon skill resolution" do
  describe WeaponSkill, "#active_version" do
    let(:ws) { create(:weapon_skill) }
    let!(:base) { create(:weapon_skill_version, weapon_skill: ws, ordinal: 0, min_uncap: 3, transcendence_stage: 0) }
    let!(:flb)  { create(:weapon_skill_version, weapon_skill: ws, ordinal: 1, min_uncap: 4, transcendence_stage: 0) }
    let!(:ulb)  { create(:weapon_skill_version, weapon_skill: ws, ordinal: 2, min_uncap: 5, transcendence_stage: 0) }
    let!(:t1)   { create(:weapon_skill_version, weapon_skill: ws, ordinal: 3, min_uncap: 5, transcendence_stage: 1) }

    it "picks the base version at or below MLB" do
      expect(ws.active_version(uncap_level: 2)).to eq(base)
      expect(ws.active_version(uncap_level: 3)).to eq(base)
    end

    it "picks FLB/ULB by uncap level" do
      expect(ws.active_version(uncap_level: 4)).to eq(flb)
      expect(ws.active_version(uncap_level: 5)).to eq(ulb)
    end

    it "picks the transcendence tier only when transcended" do
      expect(ws.active_version(uncap_level: 5, transcendence_step: 0)).to eq(ulb)
      expect(ws.active_version(uncap_level: 5, transcendence_step: 1)).to eq(t1)
    end
  end

  describe WeaponSkillDatum, ".for_skill (fallback cascade)" do
    before do
      create(:weapon_skill_datum, modifier: "Might", boost_type: "atk", series: "normal", size: "big", sl10: 15)
      create(:weapon_skill_datum, modifier: "Enmity", boost_type: "enmity", series: "normal_omega", size: "big", sl10: 10)
      create(:weapon_skill_datum, modifier: "Arts", boost_type: "skill_dmg_cap", series: "normal", size: nil, sl1: 10)
    end

    it "resolves an exact match" do
      expect(described_class.for_skill(modifier: "Might", series: "normal", size: "big").map(&:sl10)).to eq([15])
    end

    it "falls back from omega to the combined normal_omega row" do
      expect(described_class.for_skill(modifier: "Enmity", series: "omega", size: "big")).to be_present
    end

    it "resolves sizeless data regardless of the requested size" do
      expect(described_class.for_skill(modifier: "Arts", series: "normal", size: "big")).to be_present
    end

    it "returns an empty relation for an unknown modifier" do
      expect(described_class.for_skill(modifier: "Nope")).to be_empty
    end
  end

  describe WeaponSkillVersion, "#weapon_skill_effects" do
    it "resolves conditional effects by modifier" do
      WeaponSkillEffect.create!(modifier: "Pact", boost_type: "dmg_supp",
                                scaling_kind: "foe_hp_supplemental", value: 1)
      v = build(:weapon_skill_version, skill_modifier: "Pact")
      expect(v.weapon_skill_effects.pluck(:boost_type)).to include("dmg_supp")
    end

    it "is empty for a nil modifier" do
      expect(build(:weapon_skill_version, skill_modifier: nil).weapon_skill_effects).to be_empty
    end
  end

  describe Granblue::Parsers::WeaponParser, "size from the description (ground truth)" do
    let(:parser) { described_class.allocate }

    it "reads the stated size keyword" do
      expect(parser.send(:size_from_description, "Big boost to Fire allies' ATK")).to eq("big")
      expect(parser.send(:size_from_description, "Medium boost to ATK based on how low HP is")).to eq("medium")
      expect(parser.send(:size_from_description, "Massive boost to allies' ATK")).to eq("massive")
    end

    it "returns nil for sizeless or template-form descriptions" do
      expect(parser.send(:size_from_description, "Boost to skill DMG cap")).to be_nil
      expect(parser.send(:size_from_description, "[{{wsSize}}] boost to allies' ATK")).to be_nil
      expect(parser.send(:size_from_description, nil)).to be_nil
    end
  end

  describe Granblue::Parsers::WeaponParser, "#ifeq skill-name resolution (Dark Opus)" do
    let(:parser) { described_class.allocate }

    it "resolves {{#ifeq:…|Majesty III|Majesty}} to a parseable name" do
      expect(parser.send(:resolve_ifeq_name, "{{ #ifeq: {{#var: wpn_opus_version}} | omega | Majesty III | Majesty}}"))
        .to eq("Majesty")
      expect(parser.send(:resolve_ifeq_name, "{{ #ifeq: {{#var: wpn_opus_version}} | omega | Apotheosis | Apotheosis}}"))
        .to eq("Apotheosis")
    end

    it "leaves non-#ifeq names unchanged" do
      expect(parser.send(:resolve_ifeq_name, "Inferno's Might")).to eq("Inferno's Might")
    end
  end
end
