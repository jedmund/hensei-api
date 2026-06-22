# frozen_string_literal: true

require "rails_helper"

# Phase 1 — scaling-value evaluators, validated against the gbf.wiki formulas.
RSpec.describe GridDamage::Scaling do
  Datum = Struct.new(:formula_type, :sl1, :sl10, :sl15, :sl20, :sl25, :coefficient, :max_value, :size,
                     keyword_init: true)

  def datum(**attrs) = Datum.new(**attrs)

  describe "flat (SL interpolation)" do
    let(:d) { datum(formula_type: "flat", sl1: 2.0, sl10: 11.0, sl15: 15.0) }

    it "returns the anchor at a defined skill level" do
      expect(described_class.value(d, skill_level: 1)).to eq(2.0)
      expect(described_class.value(d, skill_level: 10)).to eq(11.0)
      expect(described_class.value(d, skill_level: 15)).to eq(15.0)
    end

    it "linearly interpolates between anchors" do
      expect(described_class.value(d, skill_level: 5)).to be_within(1e-9).of(6.0) # 2 + 9*(4/9)
    end

    it "clamps outside the defined range" do
      expect(described_class.value(d, skill_level: 25)).to eq(15.0)
      expect(described_class.value(datum(formula_type: "flat", sl10: 8.0), skill_level: 3)).to eq(8.0)
    end

    it "is nil when no anchors are defined" do
      expect(described_class.value(datum(formula_type: "flat"), skill_level: 15)).to be_nil
    end
  end

  describe "enmity (stronger at low HP): Modifier × (1 + 2r) × r" do
    let(:d) { datum(formula_type: "enmity", sl15: 6.0) }

    it "is 0 at full HP" do
      expect(described_class.value(d, skill_level: 15, hp_percent: 100)).to be_within(1e-9).of(0.0)
    end

    it "equals the modifier at 50% HP (r=0.5 -> (1+1)*0.5 = 1)" do
      expect(described_class.value(d, skill_level: 15, hp_percent: 50)).to be_within(1e-9).of(6.0)
    end

    it "is 3× the modifier near 0 HP" do
      expect(described_class.value(d, skill_level: 15, hp_percent: 0)).to be_within(1e-9).of(18.0)
    end
  end

  describe "stamina (coefficient curve): (HP%/(Coef−SLadj))^2.9 + 2.1" do
    # big_ii Coefficient 53.7; at SL15 the adjustment is 15 -> denom 38.7.
    let(:d) { datum(formula_type: "stamina", coefficient: 53.7, size: "big_ii") }

    it "computes the SL15/100%-HP value from the coefficient" do
      expect(described_class.value(d, skill_level: 15, hp_percent: 100)).to be_within(0.01).of(17.79)
    end

    it "drops off as HP falls (reproduces the wiki curve)" do
      expect(described_class.value(d, skill_level: 15, hp_percent: 50)).to be_within(0.02).of(4.20)
    end

    it "is constant below the 25% HP floor" do
      at25 = described_class.value(d, skill_level: 15, hp_percent: 25)
      expect(described_class.value(d, skill_level: 15, hp_percent: 5)).to be_within(1e-9).of(at25)
    end
  end

  describe "progression (per-turn, capped at the individual maximum)" do
    let(:d) { datum(formula_type: "progression", sl20: 1.5, max_value: 15.0) }

    it "accrues per turn" do
      expect(described_class.value(d, skill_level: 20, turn: 1)).to be_within(1e-9).of(1.5)
      expect(described_class.value(d, skill_level: 20, turn: 5)).to be_within(1e-9).of(7.5)
    end

    it "caps at the individual maximum" do
      expect(described_class.value(d, skill_level: 20, turn: 10)).to eq(15.0)
      expect(described_class.value(d, skill_level: 20, turn: 99)).to eq(15.0)
    end
  end

  describe "garrison (flat DEF — SL-interpolated, no HP curve)" do
    it "interpolates its SL anchors like flat" do
      d = datum(formula_type: "garrison", sl1: 3.6, sl10: 12.0, sl15: 15.0)
      expect(described_class.value(d, skill_level: 15)).to eq(15.0)
    end
  end
end
