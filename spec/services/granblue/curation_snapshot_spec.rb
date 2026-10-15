# frozen_string_literal: true

require "rails_helper"

RSpec.describe Granblue::CurationSnapshot do
  let(:path) { Rails.root.join("tmp/curation_snapshot_spec.json") }
  let(:weapon_skill) { create(:weapon_skill) }
  let(:version) { create(:weapon_skill_version, weapon_skill: weapon_skill) }
  let(:edited_at) { Time.utc(2026, 7, 6, 12) }
  let(:quiet) { StringIO.new }

  def curate_effect(attrs = {})
    WeaponSkillEffect.create!({ weapon_skill_version: version, modifier: "Axe Voltage II", boost_type: "ex_atk_sp",
                                series: "ex", scaling_kind: "per_grid_count", value: 8, condition: {},
                                manually_edited_at: edited_at, provenance: "manual" }.merge(attrs))
  end

  after { FileUtils.rm_f(path) }

  it "restores curated rows from the snapshot and is idempotent" do
    curate_effect
    WeaponSkillDatum.create!(weapon_skill_version: version, modifier: "Draconic Progression", boost_type: "atk",
                             series: "ex", formula_type: "progression", sl20: 2.0, max_value: 25,
                             manually_edited_at: edited_at, provenance: "manual")
    version.update!(suppressed_boosts: ["e_atk_prog"], overrides_edited_at: edited_at)
    described_class.export(path: path)

    WeaponSkillEffect.delete_all
    WeaponSkillDatum.delete_all
    version.update!(suppressed_boosts: [], overrides_edited_at: nil)

    first = described_class.sync(path: path, log: quiet)
    expect([first.created, first.updated, first.unmatched]).to eq([2, 1, []])
    expect(WeaponSkillEffect.sole).to have_attributes(weapon_skill_version_id: version.id, value: 8,
                                                      manually_edited_at: edited_at)
    expect(WeaponSkillDatum.sole).to have_attributes(sl20: 2.0, max_value: 25)
    expect(version.reload.suppressed_boosts).to eq(["e_atk_prog"])

    second = described_class.sync(path: path, log: quiet)
    expect([second.created, second.updated]).to eq([0, 0])
  end

  it "keeps a row that was edited after the snapshot" do
    effect = curate_effect
    described_class.export(path: path)
    effect.update!(value: 10, manually_edited_at: edited_at + 1.day) # e.g. a later admin-editor edit

    described_class.sync(path: path, log: quiet)

    expect(effect.reload.value).to eq(10)
  end

  it "overwrites a generated row with the curated one" do
    effect = curate_effect
    described_class.export(path: path)
    effect.update!(value: 4, manually_edited_at: nil, provenance: nil) # a reparse regenerated it

    described_class.sync(path: path, log: quiet)

    expect(effect.reload).to have_attributes(value: 8, manually_edited_at: edited_at)
  end

  it "removes uncurated rows of a suppressed boost type" do
    version.update!(suppressed_boosts: ["dmg_cap"], overrides_edited_at: edited_at)
    described_class.export(path: path)
    WeaponSkillEffect.create!(weapon_skill_version: version, modifier: "Astral Claw", boost_type: "dmg_cap",
                              scaling_kind: "static", value: 10, condition: {})

    report = described_class.sync(path: path, log: quiet)

    expect(report.suppressed).to eq(1)
    expect(WeaponSkillEffect.where(boost_type: "dmg_cap")).to be_empty
  end

  it "applies overrides to a version whose derived modifier isn't in the model's list" do
    version.update!(suppressed_boosts: ["e_atk"], overrides_edited_at: edited_at)
    described_class.export(path: path)
    version.update_columns(skill_modifier: "Star-Sea Sovereign's Decree", suppressed_boosts: [], overrides_edited_at: nil)

    expect { described_class.sync(path: path, log: quiet) }.not_to raise_error
    expect(version.reload.suppressed_boosts).to eq(["e_atk"])
  end

  it "reports a row that no longer matches a skill instead of guessing" do
    curate_effect
    described_class.export(path: path)
    version.skill.update!(name_en: "Renamed Skill")

    report = described_class.sync(path: path, log: quiet)

    expect(report.unmatched.size).to eq(1)
    expect(WeaponSkillEffect.where(weapon_skill_version_id: nil)).to be_empty
  end

  it "flags curation that hasn't been exported" do
    described_class.export(path: path)
    curate_effect

    drift = described_class.drift(path: path)

    expect(drift["missing"].map { |row| row["modifier"] }).to eq(["Axe Voltage II"])
    expect(drift["changed"]).to be_empty
  end
end
