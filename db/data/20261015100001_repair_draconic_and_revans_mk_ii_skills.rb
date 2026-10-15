# frozen_string_literal: true

# Repairs two families of broken wiki imports.
#
# Draconic weapons: the first skill of every Draconic and Draconic Providence weapon
# imported under one junk name ("{{ #vardefineecho: s1_name | {{"). The wiki names it
# per element and describes it as 0.1% EX ATK per turn per skill level (max 25%), the
# progression Judgment of Torrential Tides and the other Providence weapons already
# carry. The six original Draconic weapons still had a junk E. ATK (Prog.) 0.1 row in
# its place. Each version gets its element's skill, and the originals get the
# progression row. Extraction is told to leave E. ATK (Prog.) alone so a reparse of the
# renamed skill can't bring the junk row back.
#
# Revans Mk II weapons: a Mk II wiki page transcludes its Mk I page with new stats, so
# its skills are the Mk I's. Six Mk IIs imported only a junk "}}} Enforcement" (which
# resolved to the Enforcement family) and an empty junk second skill. They get copies
# of their Mk I's Enforcement and second-skill versions and effects, the junk
# Enforcement stops resolving to a family (as on Mk I), and the empty junk skill goes.
# Enforcement itself only applies "when any Omega, Taboo, or Optimus weapon skills have
# a boost of 280% or above", as the family rows already say; the Mk I rows were
# ungated. They get the gate, and the Mk I rows are stamped so a reparse keeps them.
class RepairDraconicAndRevansMkIiSkills < ActiveRecord::Migration[8.0]
  JUNK_DRACONIC_NAME = "{{ #vardefineecho%"
  JUNK_REVANS_SECOND_SKILL = "{{ #var: revans_secondskill_name }}%"
  DRACONIC_SKILL_NAMES = {
    2 => "Wilnas's Firestorm", 3 => "Wamdus's Flood", 4 => "Galleon's Landslide",
    1 => "Ewiyar's Gale", 6 => "Lu Woh's Authority", 5 => "Fediel's Eclipse"
  }.freeze
  DRACONIC_PROGRESSION = {
    modifier: "Draconic Progression", boost_type: "atk", series: "ex", formula_type: "progression",
    sl1: 0.1, sl10: 1.0, sl15: 1.5, sl20: 2.0, max_value: 25.0, aura_boostable: false
  }.freeze
  REVANS_MK_I = ["Claw of the Dragonslayer", "Concordia", "Forsaken Agastia", "Lagrange",
                 "Mortality Bow", "Spada di Vento"].freeze
  VERSION_COPY_COLUMNS = %w[skill_id ordinal unlock_level min_uncap transcendence_stage icon skill_modifier
                            skill_series skill_size main_hand_only mc_only scales_with_skill_level
                            multiplier_frame modifier_override series_override size_override
                            suppressed_boosts].freeze
  ENFORCEMENT_GATE = { "type" => "boost_level", "gte" => 280 }.freeze
  EFFECT_COPY_EXCLUDED = %w[id weapon_skill_version_id created_at updated_at manually_edited_at provenance].freeze

  def up
    [Skill, WeaponSkill, WeaponSkillVersion, WeaponSkillEffect, WeaponSkillDatum].each(&:reset_column_information)
    @now = Time.current
    repair_draconic
    REVANS_MK_I.each { |name| repair_revans_mk_ii(name) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "the replaced rows were broken imports"
  end

  private

  def repair_draconic
    junk = Skill.where("name_en LIKE ?", JUNK_DRACONIC_NAME)
    series = WeaponSeries.where(slug: %w[draconic draconic-providence])
    versions = WeaponSkillVersion.joins(weapon_skill: :weapon).includes(:skill, weapon_skill: :weapon)
                                 .where(skill_id: junk.select(:id), weapons: { weapon_series_id: series.select(:id) })
    versions.each do |version|
      weapon = version.weapon_skill.weapon
      name = DRACONIC_SKILL_NAMES[weapon.element] or next

      skill = Skill.find_or_create_by!(name_en: name, skill_type: "weapon") do |s|
        s.description_en = version.skill.description_en
      end
      version.update!(skill_id: skill.id, overrides_edited_at: @now,
                      suppressed_boosts: Array(version.suppressed_boosts) | ["e_atk_prog"])

      next if weapon.weapon_series.slug != "draconic"

      WeaponSkillEffect.where(weapon_skill_version_id: version.id, boost_type: "e_atk_prog",
                              manually_edited_at: nil).delete_all
      next if WeaponSkillDatum.exists?(weapon_skill_version_id: version.id, boost_type: "atk")

      WeaponSkillDatum.create!(DRACONIC_PROGRESSION.merge(weapon_skill_version_id: version.id,
                                                          manually_edited_at: @now, provenance: "manual"))
    end
  end

  def repair_revans_mk_ii(mk_i_name)
    mk_i = Weapon.find_by(name_en: mk_i_name) or return
    mk_ii = Weapon.find_by(name_en: "#{mk_i_name} Mk II") or return
    mk_ii_skills = WeaponSkill.where(weapon_granblue_id: mk_ii.granblue_id)
    junk_second = WeaponSkillVersion.joins(:skill).where(weapon_skill_id: mk_ii_skills.select(:id))
                                    .where("skills.name_en LIKE ?", JUNK_REVANS_SECOND_SKILL)
    curate_mk_i(mk_i)
    return unless junk_second.exists? # already repaired, or the import was fixed upstream

    WeaponSkill.where(weapon_granblue_id: mk_i.granblue_id).where.not(position: 0).find_each do |source|
      copy_weapon_skill(source, mk_ii)
    end
    junk_second.each do |version|
      next if WeaponSkillEffect.exists?(weapon_skill_version_id: version.id) ||
              WeaponSkillDatum.exists?(weapon_skill_version_id: version.id)

      weapon_skill = version.weapon_skill
      version.destroy!
      weapon_skill.destroy! unless weapon_skill.weapon_skill_versions.exists?
    end
    WeaponSkillVersion.joins(:skill).where(weapon_skill_id: mk_ii_skills.select(:id))
                      .where(skills: { name_en: "}}} Enforcement" })
                      .update_all(modifier_override: "none", overrides_edited_at: @now)
  end

  def curate_mk_i(mk_i)
    versions = WeaponSkillVersion.joins(:skill, :weapon_skill)
                                 .where(weapon_skills: { weapon_granblue_id: mk_i.granblue_id })
                                 .where.not(weapon_skills: { position: 0 })
    WeaponSkillEffect.where(weapon_skill_version_id: versions.select(:id)).find_each do |effect|
      attrs = { manually_edited_at: @now, provenance: "manual" }
      if effect.modifier.to_s.end_with?(" Enforcement") && effect.scaling_kind == "static"
        attrs[:scaling_kind] = "conditional_flat"
        attrs[:condition] = ENFORCEMENT_GATE
      end
      effect.update!(attrs)
    end
  end

  def copy_weapon_skill(source, weapon)
    target = WeaponSkill.find_or_create_by!(weapon_granblue_id: weapon.granblue_id, position: source.position)
    source.weapon_skill_versions.each do |version|
      copy = WeaponSkillVersion.find_by(weapon_skill_id: target.id, skill_id: version.skill_id) ||
             WeaponSkillVersion.create!(version.attributes.slice(*VERSION_COPY_COLUMNS).merge(weapon_skill_id: target.id))
      WeaponSkillEffect.where(weapon_skill_version_id: version.id).find_each do |effect|
        attrs = effect.attributes.except(*EFFECT_COPY_EXCLUDED)
        next if WeaponSkillEffect.exists?(attrs.slice("modifier", "boost_type", "condition")
                                               .merge("weapon_skill_version_id" => copy.id))

        WeaponSkillEffect.create!(attrs.merge("weapon_skill_version_id" => copy.id,
                                              "manually_edited_at" => @now, "provenance" => "manual"))
      end
    end
  end
end
