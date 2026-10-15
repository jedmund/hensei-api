# frozen_string_literal: true

require "rails_helper"

RSpec.describe WeaponSkills::Build::Writer do
  let(:weapon) { create(:weapon) }
  let(:gid) { weapon.granblue_id }
  let(:edited_at) { Time.utc(2026, 10, 15, 12) }

  def version(position, ordinal, name, **attrs)
    WeaponSkills::BuildResult::Version.new(weapon_granblue_id: gid, position: position, ordinal: ordinal,
                                           skill_name_en: name, skill_modifier: "Might", skill_series: "normal",
                                           skill_size: "big", transcendence_stage: 0, **attrs)
  end

  def datum(identity, boost_type, sl10)
    WeaponSkills::BuildResult::Row.new(
      version_identity: identity, kind: :datum, boost_type: boost_type, condition: nil,
      attributes: { modifier: "Might", boost_type: boost_type, series: "normal", size: "big",
                    formula_type: "flat", sl1: 1.0, sl10: sl10, sl15: 15.0 }
    )
  end

  def effect(identity, boost_type, condition)
    WeaponSkills::BuildResult::Row.new(
      version_identity: identity, kind: :effect, boost_type: boost_type, condition: condition,
      attributes: { modifier: "Might", boost_type: boost_type, series: "normal", scaling_kind: "static",
                    value: 10, condition: condition }
    )
  end

  def result(versions, rows = [])
    slots = versions.map(&:position).uniq.map { |p| WeaponSkills::BuildResult::Slot.new(weapon_granblue_id: gid, position: p) }
    WeaponSkills::BuildResult.new(weapon_granblue_id: gid, slots: slots, versions: versions, rows: rows).validate!
  end

  def write(res) = described_class.call(res)

  it "creates slots, versions and rows, then changes nothing on a second write" do
    v = version(0, 0, "Inferno's Might", unlock_level: 100, scales_with_skill_level: true)
    res = result([v], [datum(v.identity, "atk", 10.0), effect(v.identity, "da", { "type" => "x", "a" => 1 })])

    first = write(res)
    expect(first.to_h.slice(:slots_created, :versions_created, :rows_created)).to eq(slots_created: 1, versions_created: 1,
                                                                                     rows_created: 2)
    record = WeaponSkillVersion.sole
    expect(record).to have_attributes(unlock_level: 100, skill_modifier: "Might", scales_with_skill_level: true)
    expect(record.skill.name_en).to eq("Inferno's Might")

    second = write(res)
    expect(second.changed?).to be(false)
    expect(WeaponSkillVersion.sole.id).to eq(record.id)
  end

  it "updates in place, keeping ids, and removes generated rows the build no longer has" do
    v = version(0, 0, "Inferno's Might")
    write(result([v], [datum(v.identity, "atk", 10.0), datum(v.identity, "hp", 3.0)]))
    ids = [WeaponSkillVersion.sole.id, WeaponSkillDatum.find_by(boost_type: "atk").id]

    report = write(result([version(0, 0, "Inferno's Might", unlock_level: 150)], [datum(v.identity, "atk", 12.0)]))

    expect(report.to_h.slice(:versions_updated, :rows_updated, :rows_deleted)).to eq(versions_updated: 1, rows_updated: 1,
                                                                                     rows_deleted: 1)
    expect([WeaponSkillVersion.sole.id, WeaponSkillDatum.sole.id]).to eq(ids)
    expect(WeaponSkillDatum.sole.sl10).to eq(12.0)
  end

  it "never touches curated rows or the overlay's columns" do
    v = version(0, 0, "Inferno's Might")
    write(result([v]))
    record = WeaponSkillVersion.sole
    record.update_columns(modifier_override: "none", suppressed_boosts: ["hp"], overrides_edited_at: edited_at)
    curated = WeaponSkillDatum.create!(weapon_skill_version: record, modifier: "Might", boost_type: "atk", series: "normal",
                                       size: "big", sl10: 99, manually_edited_at: edited_at, provenance: "manual")

    report = write(result([v], [datum(v.identity, "atk", 10.0)]))

    expect(report.rows_kept_curated).to eq(1)
    expect(curated.reload.sl10).to eq(99)
    expect(record.reload).to have_attributes(modifier_override: "none", suppressed_boosts: ["hp"])
  end

  it "deletes a version the build no longer produces, unless it's curated" do
    a = version(0, 0, "Inferno's Might")
    b = version(1, 0, "Fire's Aegis")
    c = version(2, 0, "Fire's Majesty")
    write(result([a, b, c]))
    WeaponSkillVersion.joins(:skill).find_by(skills: { name_en: "Fire's Majesty" })
                      .update_columns(size_override: "big", overrides_edited_at: edited_at)

    report = write(result([a]))

    expect(report.to_h.slice(:versions_deleted, :versions_kept, :slots_deleted)).to eq(versions_deleted: 1, versions_kept: 1,
                                                                                       slots_deleted: 1)
    expect(WeaponSkillVersion.joins(:skill).pluck("skills.name_en")).to contain_exactly("Inferno's Might", "Fire's Majesty")
  end

  it "accepts a derived modifier outside the model's list" do
    v = version(1, 0, "Star-Sea Sovereign's Decree", skill_modifier: "Star-Sea Sovereign's Decree")

    expect { write(result([v])) }.not_to raise_error
    expect(WeaponSkillVersion.sole.skill_modifier).to eq("Star-Sea Sovereign's Decree")
  end
end
