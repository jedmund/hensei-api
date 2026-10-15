# frozen_string_literal: true

# Brings the canonical (family-level) weapon-skill data back in line with the
# July 2026 snapshots in data/. That curation was made directly in the dev
# database and never shipped, so prod still has the June rows it replaced.
#
# - Seven family rows superseded by July rows still apply alongside their
#   replacements (Wrath/Grand Epic ATK next to their EX Might Sp. rows, the
#   Surge/Exertion HP curves, Persistence's old cap) and Pendulum of Supremacy's
#   DMG Amp. 100.
# - Aramis copies stack (SRiNSO: two copies reach the 60/20 display caps), so
#   its per-copy total caps go.
# - Boost-type registry values from data/weapon_skill_boost_types.json and
#   data/boost_registry.json.
# - The family registry (data/weapon_skill_families.json): families the wiki
#   marks as not aura-boostable aren't amplified.
class RecoverJulyCanonicalSkillData < ActiveRecord::Migration[8.0]
  SUPERSEDED = [
    %w[Wrath atk per_grid_count],
    ["Grand Epic", "atk", "per_grid_count"],
    %w[Surge da current_hp_scaled],
    %w[Surge ta current_hp_scaled],
    %w[Exertion da current_hp_scaled],
    %w[Exertion ta current_hp_scaled],
    %w[Persistence dmg_supp supplemental_cap]
  ].freeze
  # NEKVvF: Supremacy's ≥280 package has no DMG Amp.
  SUPERSEDED_KEY_ROWS = [%w[pendulum-supremacy dmg_amp]].freeze
  BOOST_TYPE_KEYS = %w[plain_amp e_atk hp_dmg].freeze

  def up
    WeaponSkillEffect.reset_column_information
    WeaponSkillBoostType.reset_column_information
    WeaponSkillFamily.reset_column_information

    remove_superseded_rows
    WeaponSkillEffect.where(weapon_skill_version_id: nil, key_slug: nil, modifier: "Aramis",
                            boost_type: %w[skill_cap_sp skill_amp_sp], manually_edited_at: nil)
                     .update_all(total_cap: nil)
    restore_boost_types
    load_families
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "the replaced rows double-counted their skills"
  end

  private

  def remove_superseded_rows
    SUPERSEDED.each do |modifier, boost_type, scaling_kind|
      WeaponSkillEffect.where(weapon_skill_version_id: nil, key_slug: nil, modifier: modifier,
                              boost_type: boost_type, scaling_kind: scaling_kind,
                              manually_edited_at: nil).delete_all
    end
    SUPERSEDED_KEY_ROWS.each do |key_slug, boost_type|
      WeaponSkillEffect.where(weapon_skill_version_id: nil, key_slug: key_slug, boost_type: boost_type,
                              manually_edited_at: nil).delete_all
    end
  end

  def restore_boost_types
    types = JSON.parse(File.read(Rails.root.join("data/weapon_skill_boost_types.json")))
    types = types.values.last if types.is_a?(Hash)
    types.select { |t| BOOST_TYPE_KEYS.include?(t["key"]) }.each do |t|
      row = WeaponSkillBoostType.find_or_initialize_by(key: t["key"])
      row.assign_attributes(t.slice("name_en", "category", "grid_cap", "cap_is_flat", "stacking_rule", "notes"))
      row.save!
    end
    WeaponSkillBoostType.find_by(key: "ca_dmg")&.update!(display_cap: 120)
  end

  def load_families
    rows = JSON.parse(File.read(Rails.root.join("data/weapon_skill_families.json")))
    rows.each do |attrs|
      family = WeaponSkillFamily.find_or_initialize_by(name: attrs.fetch("name"))
      next if family.persisted? && family.manually_edited_at.present?

      family.update!(attrs.slice("aura_boostable", "boosts", "icon_stems", "color"))
    end
  end
end
