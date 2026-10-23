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

    it "lets an Exo ': Decimation' skill replace its base Supremacy" do
      s1, = slot("Dreadflame's Supremacy")
      s2, v2 = slot("Dreadflame's Supremacy: Decimation")
      weapon = double(weapon_skills: [s1, s2])
      gw = double(uncap_level: 5, transcendence_step: 0)
      expect(described_class.active_versions(weapon, gw)).to contain_exactly(v2)
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

  describe ".for_party skill levels" do
    let(:party) { create(:party) }

    # One weapon whose single skill owns an EX ATK row that varies by skill level
    # (9 / 18 / 23 / 25.5), stored at `skill_level` on an FLB copy.
    def ex_atk(scales:, skill_level:)
      weapon = create(:weapon, max_skill_level: 20)
      version = create(:weapon_skill_version, weapon_skill: create(:weapon_skill, weapon: weapon),
                                              skill_series: "ex", scales_with_skill_level: scales)
      create(:weapon_skill_datum, weapon_skill_version: version, boost_type: "atk", series: "ex",
                                  sl1: 9.0, sl10: 18.0, sl15: 23.0, sl20: 25.5)
      create(:grid_weapon, party: party, weapon: weapon, position: 0, uncap_level: 4,
                           skill_level: skill_level)
      described_class.for_party(party).map(&:value)
    end

    it "gives a skill without a skill level its full fixed value on a copy stored at SL1" do
      expect(ex_atk(scales: false, skill_level: 1)).to eq([25.5])
    end

    it "keeps a skill with a skill level on the copy's skill level" do
      expect(ex_atk(scales: true, skill_level: 1)).to eq([9.0])
    end

    it "follows a leveling skill's copy up to SL15" do
      expect(ex_atk(scales: true, skill_level: 15)).to eq([23.0])
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
