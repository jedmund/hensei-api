# frozen_string_literal: true

require "rails_helper"

RSpec.describe WeaponSkills::Build::CurationView do
  let(:weapon_skill) { create(:weapon_skill, position: 1) }
  let(:record) do
    create(:weapon_skill_version, weapon_skill: weapon_skill, ordinal: 0, suppressed_boosts: ["hp"],
                                  modifier_override: "none")
  end
  let(:version) do
    WeaponSkills::BuildResult::Version.new(weapon_granblue_id: weapon_skill.weapon_granblue_id, position: 1,
                                           ordinal: 0, skill_name_en: record.skill.name_en)
  end

  before do
    create(:weapon_skill_datum, modifier: "x", weapon_skill_version_id: record.id, boost_type: "atk",
                                manually_edited_at: Time.current)
    create(:weapon_skill_datum, modifier: "x", weapon_skill_version_id: record.id, boost_type: "da")
    WeaponSkillEffect.create!(modifier: "x", boost_type: "critical", scaling_kind: "static",
                              weapon_skill_version_id: record.id, manually_edited_at: Time.current)
  end

  it "reports curated rows, suppressed boosts and a pinned modifier" do
    view = described_class.from_database
    expect(view.curated_boost_types(version)).to eq(Set["atk", "critical"])
    expect(view.suppressed(version)).to eq(Set["hp"])
    expect(view.modifier_pinned?(version)).to be(true)
    expect(view.curated_boost_types(version)).to be_frozen
  end

  it "finds the version by skill name and ordinal when the position is unknown (overlay keys)" do
    view = described_class.from_database(weapon_granblue_ids: [weapon_skill.weapon_granblue_id])
    expect(view.suppressed(version.dup.tap { |v| v.position = nil })).to eq(Set["hp"])
  end

  it "answers empty for an unknown version" do
    other = version.dup.tap { |v| v.ordinal = 9 }
    view = described_class.from_database
    expect(view.curated_boost_types(other)).to be_empty
    expect(view.modifier_pinned?(other)).to be(false)
  end
end
