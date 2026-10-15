# frozen_string_literal: true

# Celestial weapons are identical apart from their weapon type and awakening. The second
# skill ("<name>", then "<name> II" at level 200 — {{Weapon/Common/Celestial}}
# s2_u1_lvl=200) boosts ATK, multiattack, C.A. specs and DMG cap, with bigger specs for
# allies of the weapon's specialty; only the II adds elemental ATK for them (in-game
# text: Heaven-Eye's Light "Boost to specs for bow-specialty allies" vs Ultimate
# Wisdom's Shine II "Boost to elemental ATK and specs for staff-specialty allies").
#
# The import let every II apply from 3★ (4★ copies used the II: PWwPYz's bow, F0MD7j's
# dagger), and the rows grew per weapon: family rows with E. ATK on both tiers for the
# staff/axe/gun, curated rows without it for the rest, none on two base skills. Every
# celestial skill now gets the same table, E. ATK on the II only, with family
# resolution switched off so nothing else applies.
class UnifyCelestialSpecialtySkills < ActiveRecord::Migration[8.0]
  # boost => [matching specialty, other]
  TABLE = { "atk" => [40.0, 20.0], "da" => [15.0, 10.0], "ta" => [10.0, 5.0], "ca_dmg" => [20.0, 10.0],
            "ca_dmg_cap" => [15.0, 5.0], "dmg_cap" => [10.0, 5.0] }.freeze
  II_ONLY = { "e_atk" => 10.0 }.freeze
  EXCLUDED = ["Guiding Star's Splendor", "Papillon Flamboyant"].freeze

  def up
    [WeaponSkillEffect, WeaponSkillVersion].each(&:reset_column_information)
    @now = Time.current
    series = WeaponSeries.find_by(slug: "celestial") or return

    Weapon.where(weapon_series_id: series.id).find_each do |weapon|
      specialty = GridDamage::GridComposition::PROFICIENCY_NAME.fetch(weapon.proficiency)
      specialty_versions(weapon).each { |version| rebuild(version, specialty) }
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "the replaced rows disagreed with the game"
  end

  private

  def specialty_versions(weapon)
    WeaponSkillVersion.joins(:skill, :weapon_skill).includes(:skill)
                      .where(weapon_skills: { weapon_granblue_id: weapon.granblue_id })
                      .where.not(skills: { name_en: EXCLUDED })
                      .where.not("skills.name_en LIKE '%Voltage%'")
  end

  def rebuild(version, specialty)
    name = version.skill.name_en
    tier_two = name.end_with?(" II")
    # update_columns: some of these versions carry full-name family modifiers that the
    # model's modifier list no longer validates, and they're being switched off here
    version.update_columns(modifier_override: "none", overrides_edited_at: @now,
                           **(tier_two ? { unlock_level: 200, min_uncap: 5 } : {}))

    WeaponSkillEffect.where(weapon_skill_version_id: version.id).delete_all
    TABLE.each { |boost, (matched, other)| create(version, name, boost, specialty => matched, "other" => other) }
    II_ONLY.each { |boost, matched| create(version, name, boost, specialty => matched) } if tier_two
  end

  def create(version, name, boost, specialties)
    WeaponSkillEffect.create!(
      weapon_skill_version_id: version.id, modifier: name, boost_type: boost, series: "ex",
      scaling_kind: "specialty_scaled", value: nil, value_unit: "percent",
      condition: { "specialties" => specialties }, depends_on: [], aura_boostable: false,
      seraphic_affected: false, stacking: "additive", applies_to: "element_allies",
      battle_interaction: false, manually_edited_at: @now, provenance: "manual"
    )
  end
end
