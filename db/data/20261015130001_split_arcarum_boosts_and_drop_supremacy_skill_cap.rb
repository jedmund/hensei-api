# frozen_string_literal: true

# Corrections from the P8fDVY and F0MD7j in-game panels (2026-10-15).
#
# Pendulum of Supremacy: its 280% package is ATK 40, DMG cap 7, C.B./FC amplify 100 and
# C.A. amplify (gbf.wiki Dark Opus Weapons) — no skill DMG cap. P8fDVY's Skill DMG Cap
# 78.05 = Tempering 28.05 + β Pendulum 50, with Supremacy equipped.
#
# Arcarum-only boosts have their own panel lines: F0MD7j, captured in Arcarum, lists
# "Skill Amp." 10 and "Skill Amp. (Arc)" 10 for Sephirath Brogue II, and the wiki's
# label set has N.A. Amp. (Arc), C.A. Amp. (Arc) and DMG Cap (Arc) too. Each Sephirath
# base skill's Arcarum boost moves to its (Arc) type; each II keeps its always-on boost
# and also carries the Arcarum one (the II supersedes the base skill). Brogue II's
# always-on boost is plain Skill Amp. in game, so Brogue and Corant (same wording) use
# skill_amp rather than skill_amp_sp.
class SplitArcarumBoostsAndDropSupremacySkillCap < ActiveRecord::Migration[8.0]
  # base skill => [the II's always-on type, the Arcarum type]
  SEPHIRATH = {
    "Sephirath Brogue" => %w[skill_amp skill_amp_arc],
    "Sephirath Corant" => %w[skill_amp skill_amp_arc],
    "Sephirath Haton" => %w[na_amp na_amp_arc],
    "Sephirath Fusame" => %w[na_amp na_amp_arc],
    "Sephirath Eparc" => %w[ca_amp_sp ca_amp_arc]
  }.freeze
  ARC_TYPES = {
    "skill_amp_arc" => ["Skill Amp. (Arc)", 10],
    "na_amp_arc" => ["N.A. Amp. (Arc)", nil],
    "ca_amp_arc" => ["C.A. Amp. (Arc)", nil],
    "dmg_cap_arc" => ["DMG Cap (Arc)", nil]
  }.freeze

  def up
    [WeaponSkillEffect, WeaponSkillBoostType, PanelLine].each(&:reset_column_information)
    @now = Time.current

    WeaponSkillEffect.where(weapon_skill_version_id: nil, key_slug: "pendulum-supremacy",
                            boost_type: "skill_dmg_cap").delete_all
    register_arc_types
    SEPHIRATH.each { |skill, (plain, arc)| split_sephirath(skill, plain, arc) }
    sync_panel_lines
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "the replaced rows contradicted the in-game panel"
  end

  private

  def register_arc_types
    ARC_TYPES.each do |key, (name, cap)|
      row = WeaponSkillBoostType.find_or_initialize_by(key: key)
      row.assign_attributes(name_en: name, category: "offensive", stacking_rule: "additive", cap_is_flat: false,
                            display_cap: cap, amplifiable: false,
                            notes: "Arcarum-only boost, listed apart from the always-on line in game.")
      row.save!
    end
  end

  def versions(name)
    WeaponSkillVersion.joins(:skill).where(skills: { name_en: name })
  end

  def split_sephirath(skill, plain, arc)
    versions(skill).each do |version|
      WeaponSkillEffect.where(weapon_skill_version_id: version.id).where("jsonb_exists(condition, 'arcarum')")
                       .find_each { |effect| effect.update!(boost_type: arc, manually_edited_at: @now) }
    end
    versions("#{skill} II").each do |version|
      always_on = WeaponSkillEffect.where(weapon_skill_version_id: version.id).where.not("jsonb_exists(condition, 'arcarum')")
      always_on.find_each { |effect| effect.update!(boost_type: plain, manually_edited_at: @now) }
      arcarum_row(version, skill, arc)
    end
  end

  # The II's Arcarum clause, copied from the base skill's (now Arc-typed) row.
  def arcarum_row(version, skill, arc)
    source = WeaponSkillEffect.joins(weapon_skill_version: :skill)
                              .find_by(skills: { name_en: skill }, boost_type: arc) or return
    attrs = source.attributes.except("id", "weapon_skill_version_id", "created_at", "updated_at")
    return if WeaponSkillEffect.exists?(weapon_skill_version_id: version.id, boost_type: arc)

    WeaponSkillEffect.create!(attrs.merge("weapon_skill_version_id" => version.id, "modifier" => "#{skill} II",
                                          "manually_edited_at" => @now, "provenance" => "manual"))
  end

  def sync_panel_lines
    GridDamage::PanelPresenter::LINES.each_with_index do |(key, series, label, slug, group), position|
      PanelLine.find_or_initialize_by(boost_type: key, series: series).update!(
        label_en: label, slug: slug, group_name: group, position: position
      )
    end
  end
end
