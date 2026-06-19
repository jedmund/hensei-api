# frozen_string_literal: true

require "rails_helper"

RSpec.describe GridDamage::SummonAuras do
  Row = Struct.new(:uncap_level, :transcendence_stage, :value, :element, keyword_init: true)
  # Varuna's normal_frame tiers: base 0/3/4/5 = 80/120/140/150; transcendence stages = 160/160/170.
  def varuna
    [[0, 0, 80], [3, 0, 120], [4, 0, 140], [5, 0, 150], [5, 4, 160], [5, 5, 160], [5, 6, 170]]
      .map { |u, t, v| Row.new(uncap_level: u, transcendence_stage: t, value: v) }
  end

  describe ".best_value (transcendence-aware tier selection)" do
    it "uses the ULB value when the summon is not transcended" do
      expect(described_class.best_value(varuna, uncap: 5, transcendence_step: 0)).to eq(150.0)
    end

    it "uses the transcended value at full transcendence (the 150->170 fix)" do
      expect(described_class.best_value(varuna, uncap: 6, transcendence_step: 5)).to eq(170.0)
    end

    it "respects the uncap level (MLB only)" do
      expect(described_class.best_value(varuna, uncap: 3, transcendence_step: 0)).to eq(120.0)
    end

    it "ignores transcendence tiers when not transcended even at uncap 6" do
      base_only = varuna.reject { |r| r.transcendence_stage.positive? }
      expect(described_class.best_value(base_only, uncap: 6, transcendence_step: 0)).to eq(150.0)
    end

    it "is 0 when no row applies" do
      expect(described_class.best_value([], uncap: 5, transcendence_step: 0)).to eq(0.0)
    end
  end

  describe ".slot_for" do
    it "treats main and friend summons as main-aura sources" do
      expect(described_class.slot_for(double(main?: true, friend?: false, position: -1))).to eq("main")
      expect(described_class.slot_for(double(main?: false, friend?: true, position: 6))).to eq("main")
    end

    it "treats slots 4-5 as sub-aura sources, others as none" do
      expect(described_class.slot_for(double(main?: false, friend?: false, position: 4))).to eq("sub")
      expect(described_class.slot_for(double(main?: false, friend?: false, position: 1))).to be_nil
    end
  end
end
