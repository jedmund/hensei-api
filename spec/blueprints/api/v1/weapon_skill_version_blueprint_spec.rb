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
end
