# frozen_string_literal: true

require "rails_helper"

RSpec.describe Granblue::Extractors::WeaponSkillDescriptionExtractor do
  it "writes both Heroic Tale boosts as conditional effects" do
    description = "20% boost to ATK and 10% boost to damage cap when all weapon groups are equipped"
    weapon = create(:weapon, wiki_raw: "|s1_name=Heroic Tale\n|s1_desc=#{description}\n")
    weapon_skill = create(:weapon_skill, weapon: weapon, position: 0)
    skill = create(:skill, name_en: "Heroic Tale", description_en: description)
    version = create(:weapon_skill_version, weapon_skill: weapon_skill, skill: skill)

    described_class.run(weapon: weapon)

    effects = WeaponSkillEffect.where(weapon_skill_version_id: version.id).index_by(&:boost_type)
    condition = { "type" => "count_basis_gte", "basis" => "distinct_weapon_types", "gte" => 10 }
    expect(effects.keys).to contain_exactly("atk", "dmg_cap")
    expect(effects.values).to all(have_attributes(scaling_kind: "conditional_flat", condition: condition))
    expect(effects["atk"].value.to_f).to eq(20.0)
    expect(effects["dmg_cap"].value.to_f).to eq(10.0)
  end
end
