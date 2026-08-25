# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dark Opus key effect data" do
  let(:effects) do
    payload = JSON.parse(File.read(Rails.root.join("data", "weapon_skill_effects.json")))
    payload.fetch("effects")
  end

  def key_rows(slug)
    effects.select { |row| row["key_slug"] == slug }
  end

  it "models the four legacy pendulums with canonical weapon-skill curves" do
    expected = {
      "pendulum-strength" => %w[stamina Stamina big],
      "pendulum-zeal" => %w[enmity Enmity big],
      "pendulum-strife" => %w[da Trium medium],
      "pendulum-prosperity" => %w[e_atk_prog Progression big]
    }

    expected.each do |slug, (boost_type, modifier, size)|
      row = key_rows(slug).find { |effect| effect["boost_type"] == boost_type }
      aggregate_failures(slug) do
        expect(row).to include("scaling_kind" => "weapon_skill_curve", "frame_rule" => "weapon_identity")
        expect(row.dig("condition", "curve")).to include(
          "modifier" => modifier, "series" => "normal", "size" => size
        )
      end
    end
    expect(key_rows("pendulum-strife").map { |row| row["boost_type"] }).to contain_exactly("da", "ta")
  end

  it "models passive chain stats and excludes Depravity's triggered effects" do
    expect(key_rows("chain-depravity")).to be_empty
    expect(key_rows("chain-forbiddance").to_h { |row| [row["boost_type"], row["value"]] })
      .to eq("ca_dmg" => 100.0, "ca_dmg_cap" => 30.0)
    expect(key_rows("chain-falsehood").to_h { |row| [row["boost_type"], row["value"]] })
      .to eq("charge_gain" => -100.0, "bonus_elem_dmg" => 20.0)
  end

  it "keeps chain weapon-skill stats in the Opus identity frame" do
    %w[chain-temperament chain-restoration chain-glorification].each do |slug|
      expect(key_rows(slug)).to all(include("scaling_kind" => "weapon_skill_curve",
                                            "frame_rule" => "weapon_identity"))
    end
  end

  it "applies the level 210 and 240 alpha and beta upgrades additively" do
    %w[da ta].each do |boost_type|
      upgrades = key_rows("pendulum-alpha").select { |row| row["boost_type"] == boost_type }
      expect(upgrades.map { |row| [row.dig("condition", "gte"), row["value"]] })
        .to contain_exactly([1, 2.5], [4, 2.5])
    end

    skill_hits = key_rows("pendulum-beta").select { |row| row["boost_type"] == "skill_hit" }
    expect(skill_hits.map { |row| [row.dig("condition", "gte"), row["value"]] })
      .to contain_exactly([1, 5.0], [4, 5.0])
  end
end
