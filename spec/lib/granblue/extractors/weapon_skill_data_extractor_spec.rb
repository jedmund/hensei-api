# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("lib/granblue/extractors/weapon_skill_data_extractor")

RSpec.describe Granblue::Extractors::WeaponSkillDataExtractor do
  # Fixed boost-name → key map so these golden tests don't depend on the DB.
  KEY_MAP = {
    "Might" => "atk", "HP" => "hp", "DA Rate" => "da", "TA Rate" => "ta",
    "Enmity" => "enmity", "Stamina" => "stamina", "E. ATK (Prog.)" => "e_atk_prog",
    "DEF" => "def", "Critical" => "critical", "N.A. DMG Cap" => "na_dmg_cap"
  }.freeze

  let(:extractor) { described_class.new(boost_key_by_name: KEY_MAP) }

  def rows_for(name)
    path = Rails.root.join("spec/fixtures/weapon_skill_templates/#{name}.wikitext")
    extractor.extract(File.read(path), name: name)
  end

  def find_row(rows, **criteria)
    rows.find { |r| criteria.all? { |k, v| r[k] == v } }
  end

  describe "Shape A — flat wsmod grid (Might)" do
    let(:rows) { rows_for("Might") }

    it "extracts the Normal frame at the published anchors" do
      r = find_row(rows, boost_type: "atk", series: "normal", size: "small")
      expect(r).to include(sl1: 1.0, sl10: 10.0, sl15: 12.0, sl20: 13.0, formula_type: "flat", aura_boostable: true)
    end

    it "extracts EX and Omega frames" do
      expect(find_row(rows, boost_type: "atk", series: "ex", size: "massive")).to include(sl1: 9.0)
      expect(find_row(rows, boost_type: "atk", series: "omega", size: "big")).to include(sl10: 15.0)
    end
  end

  describe "Shape A — HP grid (Aegis)" do
    it "maps to the hp boost type" do
      expect(find_row(rows_for("Aegis"), boost_type: "hp", series: "normal", size: "small"))
        .to include(sl1: 3.0, sl10: 12.0, sl15: 14.0)
    end
  end

  describe "multi-stat (Trium → DA + TA, shared values)" do
    let(:rows) { rows_for("Trium") }

    it "emits a row per boost with identical values" do
      da = find_row(rows, boost_type: "da", series: "normal_omega", size: "medium")
      ta = find_row(rows, boost_type: "ta", series: "normal_omega", size: "medium")
      expect(da).to include(sl1: 0.8, sl10: 3.5, sl15: 5.0, sl20: 6.0, sl25: 7.0)
      expect(ta.slice(:sl1, :sl10, :sl15, :sl20, :sl25)).to eq(da.slice(:sl1, :sl10, :sl15, :sl20, :sl25))
    end
  end

  describe "enmity (regression: big must hold Big's values, not Small's)" do
    it "extracts the correct Big curve" do
      expect(find_row(rows_for("Enmity"), boost_type: "enmity", series: "normal_omega", size: "big"))
        .to include(sl1: 0.83, sl10: 10.0, sl15: 12.5, sl20: 13.5, sl25: 14.5, formula_type: "enmity")
    end
  end

  describe "stamina (transposed Coefficient row)" do
    it "stores a coefficient, not SL values" do
      r = find_row(rows_for("Stamina"), boost_type: "stamina", series: "normal", size: "small")
      expect(r).to include(coefficient: 85.0, formula_type: "stamina", sl1: nil)
    end
  end

  describe "progression (per-turn + individual max)" do
    it "stores per-turn anchors and max_value" do
      expect(find_row(rows_for("Progression"), boost_type: "e_atk_prog", series: "normal_omega", size: "big"))
        .to include(sl1: 0.55, max_value: 15.0, formula_type: "progression")
    end
  end

  describe "Shape A' — plain wikitable (Garrison)" do
    let(:rows) { rows_for("Garrison") }

    it "extracts DEF with the garrison formula and normal_omega series" do
      expect(find_row(rows, boost_type: "def", series: "normal_omega", size: "small"))
        .to include(sl1: 0.5, sl10: 6.0, sl15: 7.0, formula_type: "garrison")
    end

    it "extracts the Taboo table as its own series" do
      expect(find_row(rows, boost_type: "def", series: "taboo", size: "big")).to include(sl1: 3.6)
    end
  end

  describe "Shape B — boost-per-row, sizeless (Ars)" do
    let(:rows) { rows_for("Ars") }

    it "emits sizeless EX rows per boost" do
      expect(find_row(rows, boost_type: "atk", series: "ex", size: nil)).to include(sl10: 15.0)
      expect(find_row(rows, boost_type: "hp", series: "ex", size: nil)).to include(sl10: 10.0)
      expect(find_row(rows, boost_type: "critical", series: "ex", size: nil)).to include(sl10: 15.0)
    end
  end

  describe "transposed flat table (Strike: SL in rows)" do
    it "reads the boost from the header and SL from the rows" do
      expect(find_row(rows_for("Strike"), boost_type: "na_dmg_cap", size: nil))
        .to include(sl1: 2.75, sl10: 5.0, sl15: 7.5)
    end
  end

  describe "rowspanned size carried across boost rows (Bloodrage)" do
    let(:rows) { rows_for("Bloodrage") }

    it "applies the Medium size to every boost row, not just the first" do
      expect(find_row(rows, boost_type: "atk", series: "normal", size: "medium")).to include(sl1: 3.0)
      expect(find_row(rows, boost_type: "critical", series: "normal", size: "medium")).to include(sl1: 3.2)
    end
  end
end
