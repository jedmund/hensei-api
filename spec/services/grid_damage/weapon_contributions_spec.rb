# frozen_string_literal: true

require "rails_helper"

RSpec.describe GridDamage::WeaponContributions do
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
end
