# frozen_string_literal: true

require "rails_helper"

# Whether a skill has a skill level in game is a per-skill property: Fediel's Spine's
# Eclipse's Stamina has one, its Black Covenant doesn't.
RSpec.describe WeaponSkills::Build, ".scales?" do
  let(:registry_class) { WeaponSkills::Build::Rows::Registry }
  let(:registry) do
    curve = ->(attrs) { registry_class::Curve.new(boost_type: "atk", formula_type: "flat", **attrs) }
    registry_class.new(
      data: [curve.call(modifier: "Might", series: "normal", size: "big", sl1: 6, sl10: 15, sl15: 18),
             curve.call(modifier: "Stamina", boost_type: "stamina", series: "normal", size: "big",
                        formula_type: "stamina", coefficient: 56.4),
             curve.call(modifier: "Omega Exalto", boost_type: "omega_exalto", series: "omega",
                        sl1: 20, sl10: 20, sl15: 20)],
      effects: [registry_class::Effect.new(modifier: "Voltage II", boost_type: "ex_atk_sp")]
    )
  end

  def version(modifier)
    WeaponSkills::BuildResult::Version.new(weapon_granblue_id: "1", position: 0, ordinal: 0,
                                           skill_name_en: "x", skill_modifier: modifier)
  end

  it "follows a family with values that change by skill level" do
    expect(described_class.scales?(version("Might"), registry)).to be(true)
  end

  it "counts a formula family that takes the skill level (Eclipse's Stamina)" do
    expect(described_class.scales?(version("Stamina"), registry)).to be(true)
  end

  it "gives a fixed family no skill level (Exalto, Voltage II)" do
    expect(described_class.scales?(version("Omega Exalto"), registry)).to be(false)
    expect(described_class.scales?(version("Voltage II"), registry, "Big boost to ATK")).to be(false)
  end

  it "reads a skill with no family from its text" do
    expect(described_class.scales?(version(nil), registry, "Big boost to dark allies' ATK")).to be(true) # Armed Shadow
    expect(described_class.scales?(version(nil), registry,
                                   "Supplement dark allies' C.A. DMG based on how high HP is")).to be(false) # Black Covenant
    expect(described_class.scales?(version(nil), registry, "25% boost to allies' ATK")).to be(false)
  end
end

RSpec.describe Granblue::CurationSnapshot::View, ".leveled_row?" do
  it "sees a skill's own rows that change with skill level" do
    expect(described_class.leveled_row?("sl10" => 30, "sl15" => 32, "sl20" => 35)).to be(true) # Concrio
    expect(described_class.leveled_row?("coefficient" => 50.4)).to be(true)
    expect(described_class.leveled_row?("condition" => { "type" => "copy_skill_level", "gte" => 20 })).to be(true) # Malus Essence
  end

  it "ignores fixed rows" do
    expect(described_class.leveled_row?("sl1" => 20, "sl10" => 20, "sl15" => 20)).to be(false)
    expect(described_class.leveled_row?("value" => 25, "condition" => {})).to be(false)
  end
end
