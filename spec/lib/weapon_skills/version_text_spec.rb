# frozen_string_literal: true

require "rails_helper"

RSpec.describe WeaponSkills::VersionText do
  let(:skill) { create(:skill, name_en: "Shared Might", description_en: "Shared text", description_jp: "共有") }
  let(:version) { create(:weapon_skill_version, skill: skill) }

  it "falls back to the skill's text when the version has none" do
    expect(described_class.for(version, :en)).to eq("Shared text")
    expect(described_class.for(version, :ja)).to eq("共有")
  end

  it "prefers the version's own text" do
    version.update_columns(description_en: "Tier text", description_jp: "段階")

    expect(described_class.for(version, :en)).to eq("Tier text")
    expect(described_class.for(version, :jp)).to eq("段階")
    expect(version.description_en).to eq("Tier text")
  end

  it "treats a blank column as unset" do
    version.update_columns(description_en: "")

    expect(described_class.for(version, :en)).to eq("Shared text")
  end

  it "keeps a version's text when another weapon sharing the skill rewrites it" do
    version.update_columns(description_en: "Tier text")
    sibling = create(:weapon_skill_version, skill: skill)

    # what a reparse of the sibling's weapon does: overwrite the shared Skill row
    skill.update!(description_en: "Sibling weapon's text")

    expect(described_class.for(version.reload, :en)).to eq("Tier text")
    expect(described_class.for(sibling.reload, :en)).to eq("Sibling weapon's text")
  end

  it "rejects an unknown locale" do
    expect { described_class.for(version, :fr) }.to raise_error(ArgumentError)
  end

  it "is nil without a version" do
    expect(described_class.for(nil, :en)).to be_nil
  end
end
