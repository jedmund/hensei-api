# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::WeaponSkillVersionBlueprint do
  let(:skill) { create(:skill, name_en: "Shared", description_en: "Shared text") }
  let(:version) { create(:weapon_skill_version, skill: skill) }

  it "shows the version's own tier text, keeping the description shape" do
    version.update_columns(description_en: "Tier text", description_jp: "段階")

    expect(described_class.render_as_hash(version)[:description]).to eq(en: "Tier text", ja: "段階")
  end

  it "falls back to the skill's text before a backfill" do
    expect(described_class.render_as_hash(version)[:description]).to eq(en: "Shared text", ja: nil)
  end

  it "adds display segments resolved against the weapon's element, leaving description raw" do
    version.weapon_skill.weapon.update_columns(element: GranblueEnums::ELEMENTS[:Fire])
    raw = "Boost to {{WeaponElement}} allies' {{tt|ATK|Big}}"
    version.update_columns(description_en: raw)

    hash = described_class.render_as_hash(version)

    expect(hash[:description][:en]).to eq(raw)
    expect(hash[:description_segments]).to eq(
      en: [{ text: "Boost to Fire allies' " }, { text: "ATK", tooltip: "Big" }], ja: []
    )
  end
end
