# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

RSpec.describe Granblue::WeaponSkillDataOwnershipAuditor do
  def write_json(root, relative_path, payload)
    path = root.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, JSON.generate(payload))
  end

  def write_dataset(root:, data: [], effects: [], boost_types: [])
    write_json(root, "data/weapon_skill_data.json", data)
    write_json(root, "data/weapon_skill_effects.json", { "effects" => effects })
    write_json(root, "data/weapon_skill_boost_types.json", boost_types)
  end

  def row(modifier:, boost_type:, **attrs)
    { "modifier" => modifier, "boost_type" => boost_type }.merge(attrs.transform_keys(&:to_s))
  end

  def boost_type(key, grid_cap: nil)
    {
      "key" => key,
      "name_en" => key,
      "category" => "offensive",
      "grid_cap" => grid_cap,
      "cap_is_flat" => false,
      "stacking_rule" => "additive",
      "notes" => nil
    }
  end

  around do |example|
    Dir.mktmpdir do |dir|
      @root = Pathname(dir)
      example.run
    end
  end

  it "passes when null effect rows are explicitly classified and caps live on the numeric owner" do
    write_dataset(
      root: @root,
      data: [row(modifier: "Bloodshed", boost_type: "hp_dmg")],
      effects: [
        row(modifier: "Bloodshed", boost_type: "hp_dmg", scaling_kind: "static", total_cap: 40.0),
        row(modifier: "Blow", boost_type: "bonus_elem_dmg", scaling_kind: "bonus_dmg"),
        row(modifier: "Essence", boost_type: "atk", scaling_kind: "static"),
        row(modifier: "Insignia", boost_type: "turn_dmg", scaling_kind: "per_grid_count"),
        row(modifier: "Marvel", boost_type: "skill_dmg_supp", scaling_kind: "supplemental_cap")
      ],
      boost_types: [
        boost_type("hp_dmg", grid_cap: 40.0),
        boost_type("bonus_elem_dmg"),
        boost_type("atk"),
        boost_type("turn_dmg"),
        boost_type("skill_dmg_supp")
      ]
    )

    result = described_class.run(root: @root)

    expect(result).to be_ok
    expect(result.findings).to be_empty
  end

  it "fails an unclassified scalar-like null effect row" do
    write_dataset(
      root: @root,
      effects: [row(modifier: "Mystery", boost_type: "atk", scaling_kind: "static")],
      boost_types: [boost_type("atk")]
    )

    result = described_class.run(root: @root)

    expect(result).not_to be_ok
    expect(result.findings.map(&:code)).to include("unclassified_null_effect")
  end

  it "fails a cap stranded on a null effect when weapon_skill_data owns the value" do
    write_dataset(
      root: @root,
      data: [row(modifier: "Bloodshed", boost_type: "hp_dmg")],
      effects: [row(modifier: "Bloodshed", boost_type: "hp_dmg", scaling_kind: "static", total_cap: 40.0)],
      boost_types: [boost_type("hp_dmg")]
    )

    result = described_class.run(root: @root)

    expect(result).not_to be_ok
    expect(result.findings.map(&:code)).to include("stranded_null_effect_cap")
  end

  it "allows table-valued specialty scaling with values in condition.specialties" do
    write_dataset(
      root: @root,
      effects: [
        row(
          modifier: "Pillar-Smasher's Conviction",
          boost_type: "atk",
          scaling_kind: "specialty_scaled",
          condition: { "specialties" => { "axe" => 40.0, "other" => 20.0 } }
        )
      ],
      boost_types: [boost_type("atk")]
    )

    result = described_class.run(root: @root)

    expect(result).to be_ok
  end

  it "fails boost types emitted by data/effects but missing from the registry" do
    write_dataset(
      root: @root,
      data: [row(modifier: "Might", boost_type: "atk")],
      boost_types: []
    )

    result = described_class.run(root: @root)

    expect(result).not_to be_ok
    expect(result.findings.map(&:code)).to include("unregistered_boost_type")
  end
end
