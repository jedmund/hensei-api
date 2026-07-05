# frozen_string_literal: true

require "rails_helper"

# Phase 4 — frame math: auras + Exalto inside the per-frame multiplier, frames multiply.
RSpec.describe GridDamage::FrameMath do
  describe "#frame (ATK boost = 1 + mod × (1 + aura + exalto) + extra)" do
    it "amplifies the Normal mod by aura + Exalto (additively)" do
      # 58.5% Might, Optimus aura 150%, Optimus Exalto 90% → 1 + 0.585 × 3.4 = 2.989
      r = described_class.compute(normal: { atk: 58.5 }, auras: { optimus: 150 }, exalto: { optimus: 90 })
      expect(r[:normal][:atk]).to be_within(1e-6).of(2.989)
    end

    it "adds NormSummon-style boosts directly (not through the aura multiplier)" do
      # 10% mod, no aura, +50% Normal-ATK summon → 1 + 0.10 + 0.50 = 1.60
      r = described_class.compute(normal: { atk: 10 }, auras: { normal_summon: 50 })
      expect(r[:normal][:atk]).to be_within(1e-6).of(1.60)
    end

    it "gives the EX frame no ordinary aura" do
      r = described_class.compute(ex: { atk: 25 }, auras: { optimus: 150, omega: 100 })
      expect(r[:ex][:atk]).to be_within(1e-6).of(1.25)
    end

    it "applies the same aura form to Enmity/Stamina" do
      # 10% enmity, Optimus aura 150% → 1 + 0.10 × 2.5 = 1.25
      r = described_class.compute(normal: { enmity: 10 }, auras: { optimus: 150 })
      expect(r[:normal][:enmity]).to be_within(1e-6).of(1.25)
    end
  end

  describe "composite + elemental" do
    let(:r) do
      described_class.compute(
        normal: { atk: 58.5 }, omega: { atk: 36 }, ex: { atk: 25 },
        auras: { optimus: 150, omega: 100, elemental: 100 }, exalto: { optimus: 90 },
        advantage: :superior
      )
    end

    it "multiplies the frames into NormalOmegaEX" do
      # 2.989 × 1.72 × 1.25
      expect(r[:normal_omega_ex]).to be_within(1e-3).of(6.4263)
    end

    it "builds Elemental from superiority + elemental auras + progression" do
      # 1 + (50 + 100 + 0)/100
      expect(r[:elemental]).to be_within(1e-9).of(2.5)
    end

    it "multiplies composite × elemental into the grid multiplier" do
      expect(r[:grid_multiplier]).to be_within(1e-2).of(16.066)
    end

    it "caps Progression's elemental contribution at 75%" do
      capped = described_class.compute(progression: 120, advantage: :neutral)
      expect(capped[:elemental]).to be_within(1e-9).of(1.75)
    end

    it "applies elemental inferiority as −25%" do
      inf = described_class.compute(advantage: :inferior)
      expect(inf[:elemental]).to be_within(1e-9).of(0.75)
    end
  end

  it "exposes per-frame Enhancement % matching the in-game panel" do
    r = described_class.compute(normal: { atk: 100 }, auras: { optimus: 170 })
    # 1 + 1.0 × 2.7 = 3.7 → enhancement 270%
    expect(described_class.enhancement_percents(r)[:normal]).to eq(270.0)
  end
end
