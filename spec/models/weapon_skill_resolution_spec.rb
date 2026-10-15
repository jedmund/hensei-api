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
                                scaling_kind: "supplemental_cap", value: 1)
      v = build(:weapon_skill_version, skill_modifier: "Pact")
      expect(v.weapon_skill_effects.pluck(:boost_type)).to include("dmg_supp")
    end

    it "is empty for a nil modifier" do
      expect(build(:weapon_skill_version, skill_modifier: nil).weapon_skill_effects).to be_empty
    end
  end

  # Per boost_type: curated row → suppressed (nothing) → family default → generated row.
  describe WeaponSkillVersion, "read-time precedence" do
    let(:version) { create(:weapon_skill_version, skill_modifier: "Voltage", skill_series: :ex, skill_size: :medium) }

    def effect(value, version: nil, curated: false, boost_type: "ex_atk_sp", modifier: "Voltage")
      WeaponSkillEffect.create!(modifier: modifier, boost_type: boost_type, scaling_kind: "per_grid_count",
                                value: value, count_basis: "same_weapon_type", weapon_skill_version: version,
                                manually_edited_at: (Time.current if curated))
    end

    def datum(sl10, version: nil, curated: false, boost_type: "atk", modifier: "Voltage")
      create(:weapon_skill_datum, modifier: modifier, boost_type: boost_type, series: "ex", size: "medium",
                                  sl10: sl10, weapon_skill_version: version,
                                  manually_edited_at: (Time.current if curated))
    end

    def effect_values = version.weapon_skill_effects.map { |e| e.value.to_f }.sort
    def data_values = version.weapon_skill_data.map { |d| d.sl10.to_f }.sort

    it "lets the family default beat a generated row" do
      effect(4)
      effect(8, version: version, modifier: "Axe Voltage II")
      expect(effect_values).to eq([4.0])
    end

    it "lets a curated row beat the family default" do
      effect(4)
      effect(8, version: version, curated: true, modifier: "Axe Voltage II")
      expect(effect_values).to eq([8.0])
    end

    it "falls back to a generated row when the family has nothing for the boost type" do
      effect(4)
      effect(10, version: version, boost_type: "dmg_cap", modifier: "Axe Voltage II")
      expect(version.weapon_skill_effects.map(&:boost_type)).to contain_exactly("ex_atk_sp", "dmg_cap")
    end

    it "hides the family and generated rows of a suppressed boost type, but not a curated row" do
      effect(4)
      datum(10)
      version.update!(suppressed_boosts: %w[ex_atk_sp atk])
      expect(version.weapon_skill_effects).to be_empty
      expect(version.weapon_skill_data).to be_empty

      effect(8, version: version, curated: true, modifier: "Axe Voltage II")
      expect(effect_values).to eq([8.0])
    end

    it "keeps the family when the build's extraction is fully suppressed (\"*\")" do
      effect(4)
      effect(10, version: version, boost_type: "dmg_cap", modifier: "Axe Voltage II")
      version.update!(suppressed_boosts: ["*"])
      expect(effect_values).to eq([4.0])
    end

    it "resolves data the same way" do
      datum(10)
      datum(20, version: version, modifier: "Axe Voltage II")
      expect(data_values).to eq([10.0])

      WeaponSkillDatum.where(weapon_skill_version: version).update_all(manually_edited_at: Time.current)
      expect(data_values).to eq([20.0])
    end

    it "resolves data and effects separately" do
      datum(10, boost_type: "ex_atk_sp")
      effect(4)
      expect(version.weapon_skill_data.map(&:boost_type)).to eq(["ex_atk_sp"])
      expect(version.weapon_skill_effects.map(&:boost_type)).to eq(["ex_atk_sp"])
    end
  end
end
