# frozen_string_literal: true

require "rails_helper"

# Moved from the WeaponParser spec when the old parser's skill code was deleted. Uses the
# Hrunting fixture (granblue_id 1040022900): an Illustrious weapon with 4 skill slots whose
# tiers span base/FLB and Transcendence stages.
RSpec.describe WeaponSkills::Build::Structure::Tiers do
  let(:fixture) { Rails.root.join("spec/fixtures/wiki/hrunting.txt").read }
  let(:skills) { described_class.slots(WeaponSkills::Build::Structure::Wikitext.fields(fixture)) }

  describe ".tier_for" do
    it "maps unlock level to uncap/transcendence tier" do
      expect(described_class.tier_for(nil)).to eq(min_uncap: 3, transcendence_stage: 0)
      expect(described_class.tier_for(100)).to eq(min_uncap: 3, transcendence_stage: 0)
      expect(described_class.tier_for(150)).to eq(min_uncap: 4, transcendence_stage: 0)
      expect(described_class.tier_for(200)).to eq(min_uncap: 5, transcendence_stage: 0)
      expect(described_class.tier_for(210)).to eq(min_uncap: 5, transcendence_stage: 1)
      expect(described_class.tier_for(230)).to eq(min_uncap: 5, transcendence_stage: 3)
      expect(described_class.tier_for(250)).to eq(min_uncap: 5, transcendence_stage: 5)
    end
  end

  describe ".main_hand_only_description?" do
    it "does not gate an always-on first clause when only a later clause requires main hand" do
      description = "Boost to DEF for the first 8 turns<br>When main weapon: Reduce Poison damage"

      expect(described_class.main_hand_only_description?(description)).to be(false)
    end

    it "keeps a first-clause main-hand restriction" do
      description = "When main weapon (MC only): Boost to skill damage<br>Another effect"

      expect(described_class.main_hand_only_description?(description)).to be(true)
    end
  end

  describe ".size_from_description" do
    it "reads the stated size keyword" do
      expect(described_class.size_from_description("Big boost to Fire allies' ATK")).to eq("big")
      expect(described_class.size_from_description("Medium boost to ATK based on how low HP is")).to eq("medium")
      expect(described_class.size_from_description("Massive boost to allies' ATK")).to eq("massive")
    end

    it "returns nil for sizeless or template-form descriptions" do
      expect(described_class.size_from_description("Boost to skill DMG cap")).to be_nil
      expect(described_class.size_from_description("[{{wsSize}}] boost to allies' ATK")).to be_nil
      expect(described_class.size_from_description(nil)).to be_nil
    end
  end

  describe ".resolve_ifeq_name (Dark Opus)" do
    it "resolves {{#ifeq:…|Majesty III|Majesty}} to a parseable name" do
      expect(described_class.resolve_ifeq_name("{{ #ifeq: {{#var: wpn_opus_version}} | omega | Majesty III | Majesty}}"))
        .to eq("Majesty")
      expect(described_class.resolve_ifeq_name("{{ #ifeq: {{#var: wpn_opus_version}} | omega | Apotheosis | Apotheosis}}"))
        .to eq("Apotheosis")
    end

    it "leaves non-#ifeq names unchanged" do
      expect(described_class.resolve_ifeq_name("Inferno's Might")).to eq("Inferno's Might")
    end
  end

  describe ".slots" do
    it "extracts all 4 slots" do
      expect(skills.map { |s| s[:position] }).to eq([0, 1, 2, 3])
    end

    it "orders slot 0's tiers by level, not suffix: base → T1@210 → T4@240" do
      versions = skills[0][:versions]
      expect(versions.map { |v| v[:ordinal] }).to eq([0, 1, 2])
      expect(versions.map { |v| v[:unlock_level] }).to eq([nil, 210, 240])
      expect(versions.map { |v| [v[:min_uncap], v[:transcendence_stage]] }).to eq([[3, 0], [5, 1], [5, 4]])
      expect(versions.map { |v| v[:name_en] }).to eq(
        ["Savage Mythology", "Savage Mythology II", "Savage Mythology III"]
      )
    end

    it "gives slot 1 a base tier and T2@220" do
      versions = skills[1][:versions]
      expect(versions.map { |v| v[:unlock_level] }).to eq([nil, 220])
      expect(versions.map { |v| v[:transcendence_stage] }).to eq([0, 2])
    end

    it "reads slot 2 as a single FLB-tier grid skill (Terra's Enmity)" do
      versions = skills[2][:versions]
      expect(versions.size).to eq(1)
      expect(versions[0]).to include(unlock_level: 150, min_uncap: 4, transcendence_stage: 0,
                                     modifier: "Enmity", main_hand_only: false)
    end

    it "gives slot 3 T3@230 and T5@250" do
      versions = skills[3][:versions]
      expect(versions.map { |v| v[:unlock_level] }).to eq([230, 250])
      expect(versions.map { |v| v[:transcendence_stage] }).to eq([3, 5])
    end

    it "derives main_hand_only / mc_only from the description text" do
      expect(skills[0][:versions].map { |v| v[:main_hand_only] }).to all(be true)
      expect(skills[0][:versions].map { |v| v[:mc_only] }).to all(be true)
      # Abandoned Role is "When main weapon" but not "(MC only)"
      expect(skills[1][:versions].map { |v| v[:main_hand_only] }).to all(be true)
      expect(skills[1][:versions].map { |v| v[:mc_only] }).to all(be false)
    end

    it "never collects the charge attack as a weapon skill" do
      names = skills.flat_map { |s| s[:versions] }.map { |v| v[:name_en] }
      expect(names).not_to include("Here at Last", "Demise at Last")
    end
  end
end
