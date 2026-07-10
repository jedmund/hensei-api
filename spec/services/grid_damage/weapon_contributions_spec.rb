# frozen_string_literal: true

require "rails_helper"

RSpec.describe GridDamage::WeaponContributions do
  describe ".active_versions" do
    def slot(name)
      version = double(skill: double(name_en: name))
      [double(active_version: version), version]
    end

    it "keeps only the highest variant of an upgraded skill pair (X vs X II)" do
      s1, = slot("Sephirath Brogue")
      s2, v2 = slot("Sephirath Brogue II")
      s3, v3 = slot("Tidings of the New World")
      weapon = double(weapon_skills: [s1, s2, s3])
      gw = double(uncap_level: 4, transcendence_step: 0)
      expect(described_class.active_versions(weapon, gw)).to contain_exactly(v2, v3)
    end
  end

  describe ".skill_level_for" do
    def sl(weapon_max:, uncap:, transc: 0)
      weapon = instance_double(Weapon, max_skill_level: weapon_max)
      gw = instance_double(GridWeapon, uncap_level: uncap, transcendence_step: transc)
      described_class.skill_level_for(weapon, gw)
    end

    it "reads the copy's uncap cap, not the weapon's maximum" do
      # An FLB (4★) copy of an ULB-capable weapon plays at SL15, not SL20.
      expect(sl(weapon_max: 20, uncap: 4)).to eq(15)
    end

    it "reaches the weapon max at ULB" do
      expect(sl(weapon_max: 20, uncap: 5)).to eq(20)
      expect(sl(weapon_max: 20, uncap: 6)).to eq(20)
    end

    it "caps below MLB at SL10" do
      expect(sl(weapon_max: 20, uncap: 2)).to eq(10)
    end

    it "clamps to the weapon's own maximum (FLB-only weapons)" do
      expect(sl(weapon_max: 15, uncap: 5)).to eq(15)
    end

    it "adds +5 only at the final transcendence stage" do
      expect(sl(weapon_max: 20, uncap: 6, transc: 4)).to eq(20)
      expect(sl(weapon_max: 20, uncap: 6, transc: 5)).to eq(25)
    end

    it "defaults a weapon without max_skill_level to SL15" do
      expect(sl(weapon_max: nil, uncap: 5)).to eq(15)
    end
  end

  describe ".series_summon_boosted?" do
    it "keeps ancestral weapons flat before registry data is seeded" do
      series = instance_double(WeaponSeries, slug: "ancestral", summon_boosted: nil)

      expect(described_class.series_summon_boosted?(series)).to be(false)
    end

    it "honors the registry flag when present" do
      series = instance_double(WeaponSeries, slug: "ancestral", summon_boosted: false)

      expect(described_class.series_summon_boosted?(series)).to be(false)
    end
  end
end
