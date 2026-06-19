# frozen_string_literal: true

require "rails_helper"

# Phase 2 — per-boost_type aggregation (stacking rules, caps, main-hand gating).
RSpec.describe GridDamage::Aggregator do
  C = GridDamage::Aggregator::Contribution
  Meta = Struct.new(:stacking_rule, :grid_cap, :cap_is_flat, keyword_init: true)

  def contrib(boost_type:, value:, series: "normal", main_hand_only: false, mainhand: false)
    C.new(boost_type:, series:, value:, main_hand_only:, mainhand:)
  end

  let(:boost_types) do
    {
      "atk" => Meta.new(stacking_rule: "multiplicative_by_series", grid_cap: nil, cap_is_flat: false),
      "da"  => Meta.new(stacking_rule: "additive", grid_cap: nil, cap_is_flat: false),
      "hp"  => Meta.new(stacking_rule: "additive", grid_cap: 400.0, cap_is_flat: false),
      "ca_supp" => Meta.new(stacking_rule: "additive", grid_cap: 1_000_000.0, cap_is_flat: true),
      "elem_amplify" => Meta.new(stacking_rule: "highest_only", grid_cap: nil, cap_is_flat: false)
    }
  end

  def agg(contribs) = described_class.aggregate(contribs, boost_types:)

  describe "additive" do
    it "sums contributions of the same boost_type" do
      r = agg([contrib(boost_type: "da", value: 10), contrib(boost_type: "da", value: 8.5)])["da"]
      expect(r.total).to eq(18.5)
      expect(r.capped).to be(false)
    end

    it "leaves a total under its cap unchanged" do
      r = agg([contrib(boost_type: "hp", value: 100), contrib(boost_type: "hp", value: 120)])["hp"]
      expect(r.total).to eq(220.0)
      expect(r.capped).to be(false)
    end

    it "clamps a total over its cap and flags it" do
      r = agg([contrib(boost_type: "hp", value: 300), contrib(boost_type: "hp", value: 200)])["hp"]
      expect(r.raw).to eq(500.0)
      expect(r.total).to eq(400.0)
      expect(r.capped).to be(true)
    end

    it "applies flat caps the same way (C.A. supplemental)" do
      r = agg([contrib(boost_type: "ca_supp", value: 700_000), contrib(boost_type: "ca_supp", value: 500_000)])["ca_supp"]
      expect(r.total).to eq(1_000_000.0)
      expect(r.cap_is_flat).to be(true)
      expect(r.capped).to be(true)
    end
  end

  describe "highest_only" do
    it "keeps only the largest contribution" do
      r = agg([contrib(boost_type: "elem_amplify", value: 15), contrib(boost_type: "elem_amplify", value: 20)])["elem_amplify"]
      expect(r.total).to eq(20.0)
    end
  end

  describe "multiplicative_by_series" do
    it "keeps per-series subtotals (frames multiply later, not here)" do
      r = agg([
        contrib(boost_type: "atk", series: "normal", value: 15),
        contrib(boost_type: "atk", series: "normal", value: 18),
        contrib(boost_type: "atk", series: "omega", value: 20)
      ])["atk"]
      expect(r.by_series).to eq("normal" => 33.0, "omega" => 20.0)
      expect(r.capped).to be(false)
    end
  end

  describe "main-hand gating" do
    it "excludes a main-hand-only skill when the weapon isn't the main weapon" do
      r = agg([contrib(boost_type: "da", value: 5, main_hand_only: true, mainhand: false)])
      expect(r).to be_empty
    end

    it "includes a main-hand-only skill on the main weapon" do
      r = agg([contrib(boost_type: "da", value: 5, main_hand_only: true, mainhand: true)])["da"]
      expect(r.total).to eq(5.0)
    end
  end

  it "skips contributions with a nil value (unresolved skills)" do
    r = agg([contrib(boost_type: "da", value: nil), contrib(boost_type: "da", value: 7)])["da"]
    expect(r.total).to eq(7.0)
  end

  describe "shared_cap_group" do
    def shared(value)
      C.new(boost_type: "atk", series: "ex", value:, shared_cap_group: "g", cap: 80.0, mainhand: false)
    end

    it "pools group members and caps the total at the group cap" do
      r = agg([shared(60), shared(40)])["atk"] # 100 -> capped 80
      expect(r.by_series["ex"]).to eq(80.0)
    end

    it "leaves a group under its cap untouched" do
      r = agg([shared(15), shared(20)])["atk"]
      expect(r.by_series["ex"]).to eq(35.0)
    end
  end
end
