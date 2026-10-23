# frozen_string_literal: true

require "rails_helper"

RSpec.describe "source-complete unresolved family data" do
  let(:data_rows) do
    JSON.parse(Rails.root.join("data/weapon_skill_data.json").read)
  end
  let(:effect_rows) do
    JSON.parse(Rails.root.join("data/weapon_skill_effects.json").read).fetch("effects")
  end
  let(:turn_gated_modifiers) do
    ["Betrayal", "Preemptive Blade", "Preemptive Wall", "Rose's Refuge"]
  end

  it "moves first-eight-turn curves out of unconditional skill data" do
    modifiers = data_rows.map { |row| row.fetch("modifier") }

    expect(modifiers).not_to include("Betrayal", "Preemptive Blade", "Preemptive Wall")
  end

  it "models all first-eight-turn curves as inclusive turn-gated effects" do
    rows = effect_rows.select do |row|
      turn_gated_modifiers.include?(row["modifier"])
    end

    expect(rows.size).to eq(4)
    expect(rows).to all(include("scaling_kind" => "weapon_skill_curve"))
    expect(rows.map { |row| row.dig("condition", "type") }.uniq).to eq(["turn_lte"])
    expect(rows.map { |row| row.dig("condition", "lte") }.uniq).to eq([8])
  end

  it "models Artistry and Staff Resonance from their source-complete values" do
    technical = effect_rows.find { |row| row["modifier"] == "Technical Artistry" }
    covert = effect_rows.find { |row| row["modifier"] == "Covert Artistry" }
    staff = effect_rows.select { |row| row["modifier"] == "Staff Resonance" }

    expect(technical).to include("boost_type" => "skill_dmg", "value" => 20.0,
                                 "applies_to" => "mc_only")
    expect(covert).to include("boost_type" => "ca_dmg", "value" => 20.0,
                              "applies_to" => "mc_only")
    expect(staff.map { |row| row["boost_type"] }).to contain_exactly("da", "ta")
    expect(staff).to all(include("value" => 1.0, "count_basis" => "same_weapon_type",
                                 "count_cap" => 10, "stacking" => "highest_only"))
  end
end
