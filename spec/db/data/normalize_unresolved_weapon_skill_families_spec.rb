# frozen_string_literal: true

require "rails_helper"

RSpec.describe "NormalizeUnresolvedWeaponSkillFamilies" do
  let(:migration_class) do
    unless defined?(NormalizeUnresolvedWeaponSkillFamilies)
      require Rails.root.join("db/data/20260717190000_normalize_unresolved_weapon_skill_families")
    end
    NormalizeUnresolvedWeaponSkillFamilies
  end

  it "backfills exact classifications and installs the canonical effects" do
    preemptive = create(:weapon_skill_version,
                        skill: create(:skill, name_en: "Preemptive Frost Blade"))
    preemptive.update_columns(skill_modifier: "Frost Blade")
    mutiny = create(:weapon_skill_version, skill: create(:skill, name_en: "Mutiny's Frost Blade"))
    mutiny.update_columns(skill_modifier: "Frost Blade")
    refuge = create(:weapon_skill_version, skill: create(:skill, name_en: "Rose's Refuge"),
                                           main_hand_only: true)
    refuge.update_columns(skill_modifier: "Refuge")
    technical = create(:weapon_skill_version,
                       skill: create(:skill, name_en: "Technical Artistry"),
                       skill_modifier: "Technical Artistry", scales_with_skill_level: true)
    linked = create(:weapon_skill_datum, modifier: "Technical Artistry", boost_type: "skill_dmg",
                                         weapon_skill_version_id: technical.id)

    ["Betrayal", "Preemptive Blade", "Preemptive Wall"].each do |modifier|
      create(:weapon_skill_datum, modifier: modifier, size: nil)
    end

    migration_class.new.up

    expect(preemptive.reload).to have_attributes(skill_modifier: "Preemptive Blade",
                                                 scales_with_skill_level: true)
    expect(mutiny.reload).to have_attributes(skill_modifier: nil, scales_with_skill_level: false)
    expect(refuge.reload).to have_attributes(skill_modifier: "Rose's Refuge", main_hand_only: false,
                                             scales_with_skill_level: true)
    expect(technical.reload.scales_with_skill_level).to be(false)
    expect(WeaponSkillDatum.where(id: linked.id)).to be_empty
    expect(WeaponSkillDatum.where(modifier: migration_class::CURVE_DATA_MODIFIERS)).to be_empty
    expect(WeaponSkillEffect.where(modifier: migration_class::EFFECT_MODIFIERS,
                                   weapon_skill_version_id: nil).count).to eq(8)
    expect(WeaponSkillBoostType.find_by(key: "skill_dmg")).to be_present
  end

  it "refuses to remove a generated row that was manually edited" do
    technical = create(:weapon_skill_version,
                       skill: create(:skill, name_en: "Technical Artistry"),
                       skill_modifier: "Technical Artistry", scales_with_skill_level: true)
    linked = create(:weapon_skill_datum, modifier: "Technical Artistry", boost_type: "skill_dmg",
                                         weapon_skill_version_id: technical.id,
                                         sl15: 17, manually_edited_at: 1.day.ago)

    expect { migration_class.new.up }
      .to raise_error(RuntimeError, /Manual unresolved-family rows require review/)
    expect(technical.reload.scales_with_skill_level).to be(true)
    expect(linked.reload.sl15).to eq(17)
  end
end
