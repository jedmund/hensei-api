# frozen_string_literal: true

# Promotes the remaining source-complete families into canonical effects and
# fixes the exact parser classifications already stored in production. This is
# deliberately a targeted backfill: it does not reparse the weapon catalog.
class NormalizeUnresolvedWeaponSkillFamilies < ActiveRecord::Migration[8.0]
  PREEMPTIVE_BLADE_NAMES = [
    "Preemptive Frost Blade", "Preemptive Light Blade",
    "Preemptive Shadow Blade", "Preemptive Terra Blade"
  ].freeze
  MUTINY_NAMES = [
    "Mutiny's Frost Blade", "Mutiny's Light Blade",
    "Mutiny's Shadow Blade", "Mutiny's Terra Blade"
  ].freeze
  EFFECT_MODIFIERS = [
    "Betrayal", "Covert Artistry", "Preemptive Blade", "Preemptive Wall",
    "Rose's Refuge", "Staff Resonance", "Technical Artistry"
  ].freeze
  CURVE_DATA_MODIFIERS = ["Betrayal", "Preemptive Blade", "Preemptive Wall"].freeze
  GENERATED_LINKED_BOOSTS = {
    "Technical Artistry" => %w[skill_dmg],
    "Covert Artistry" => %w[ca_dmg],
    "Staff Resonance" => %w[da ta]
  }.freeze
  SNAPSHOT_COLUMNS = %w[
    modifier boost_type series scaling_kind value value_unit per_copy_cap total_cap
    shared_cap_group cap_formula count_basis count_cap condition target_instance depends_on
    aura_boostable seraphic_affected stacking applies_to battle_interaction notes key_slug frame_rule
  ].freeze
  EXPECTED_EFFECT_ROWS = 8

  def up
    WeaponSkillEffect.reset_column_information
    assert_no_manual_conflicts!
    upsert_skill_damage_metadata
    normalize_versions
    remove_obsolete_curve_data
    remove_generated_linked_rows
    sync_canonical_effects
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "the old classifications and conditionless curves were incorrect"
  end

  private

  def assert_no_manual_conflicts!
    conflicts = []

    manual_curve_ids = WeaponSkillDatum.where(
      weapon_skill_version_id: nil, modifier: CURVE_DATA_MODIFIERS
    ).where.not(manually_edited_at: nil).pluck(:id)
    conflicts << "canonical data #{manual_curve_ids.join(',')}" if manual_curve_ids.any?

    manual_effect_ids = WeaponSkillEffect.where(
      weapon_skill_version_id: nil, key_slug: nil, modifier: EFFECT_MODIFIERS
    ).where.not(manually_edited_at: nil).pluck(:id)
    conflicts << "canonical effects #{manual_effect_ids.join(',')}" if manual_effect_ids.any?

    GENERATED_LINKED_BOOSTS.each do |modifier, boost_types|
      version_ids = version_ids_for(modifier)
      manual_data_ids = WeaponSkillDatum.where(
        weapon_skill_version_id: version_ids, boost_type: boost_types
      ).where.not(manually_edited_at: nil).pluck(:id)
      conflicts << "#{modifier} linked data #{manual_data_ids.join(',')}" if manual_data_ids.any?

      manual_linked_effect_ids = WeaponSkillEffect.where(
        weapon_skill_version_id: version_ids, boost_type: boost_types
      ).where.not(manually_edited_at: nil).pluck(:id)
      if manual_linked_effect_ids.any?
        conflicts << "#{modifier} linked effects #{manual_linked_effect_ids.join(',')}"
      end
    end

    return if conflicts.empty?

    raise "Manual unresolved-family rows require review before migration: #{conflicts.join('; ')}"
  end

  def upsert_skill_damage_metadata
    WeaponSkillBoostType.find_or_initialize_by(key: "skill_dmg").update!(
      name_en: "Skill DMG", category: "offensive", grid_cap: nil,
      cap_is_flat: false, stacking_rule: "additive", amplifiable: false,
      notes: "Boost to skill damage."
    )
    position = GridDamage::PanelPresenter::LINES.index { |line| line.first == "skill_dmg" }
    line = GridDamage::PanelPresenter::LINES.fetch(position)
    PanelLine.find_or_initialize_by(boost_type: line[0], series: line[1]).update!(
      label_en: line[2], slug: line[3], group_name: line[4], position: position
    )
  end

  def normalize_versions
    editable_versions_for(PREEMPTIVE_BLADE_NAMES).update_all(
      skill_modifier: "Preemptive Blade", scales_with_skill_level: true, updated_at: Time.current
    )
    editable_versions_for(MUTINY_NAMES).update_all(
      skill_modifier: nil, scales_with_skill_level: false, updated_at: Time.current
    )
    editable_versions_for(["Rose's Refuge"]).update_all(
      skill_modifier: "Rose's Refuge", main_hand_only: false,
      scales_with_skill_level: true, updated_at: Time.current
    )
    editable_versions_for(GENERATED_LINKED_BOOSTS.keys).update_all(
      scales_with_skill_level: false, updated_at: Time.current
    )
  end

  def editable_versions_for(names)
    WeaponSkillVersion.joins(:skill)
                      .where(skills: { name_en: names })
                      .where(modifier_override: [nil, ""])
  end

  def remove_obsolete_curve_data
    scope = WeaponSkillDatum.where(weapon_skill_version_id: nil, modifier: CURVE_DATA_MODIFIERS)
    manual = scope.where.not(manually_edited_at: nil)
    if manual.exists?
      raise "Manual conditionless curve rows require review: #{manual.pluck(:modifier).uniq.join(', ')}"
    end

    scope.delete_all
  end

  def remove_generated_linked_rows
    GENERATED_LINKED_BOOSTS.each do |modifier, boost_types|
      version_ids = version_ids_for(modifier)
      WeaponSkillDatum.where(weapon_skill_version_id: version_ids, boost_type: boost_types,
                             manually_edited_at: nil).delete_all
      WeaponSkillEffect.where(weapon_skill_version_id: version_ids, boost_type: boost_types,
                              manually_edited_at: nil).delete_all
    end
  end

  def version_ids_for(modifier)
    WeaponSkillVersion.joins(:skill)
                      .where(skills: { name_en: modifier })
                      .select(:id)
  end

  def sync_canonical_effects
    rows = snapshot_rows.select do |row|
      row["key_slug"].nil? && EFFECT_MODIFIERS.include?(row["modifier"])
    end
    unless rows.size == EXPECTED_EFFECT_ROWS
      raise "Expected #{EXPECTED_EFFECT_ROWS} unresolved-family effects, found #{rows.size}"
    end

    scope = WeaponSkillEffect.where(weapon_skill_version_id: nil, key_slug: nil,
                                    modifier: EFFECT_MODIFIERS)
    manual = scope.where.not(manually_edited_at: nil)
    if manual.exists?
      raise "Manual canonical effects require review: #{manual.pluck(:modifier).uniq.join(', ')}"
    end
    scope.delete_all

    rows.each do |row|
      WeaponSkillEffect.create!(row.slice(*SNAPSHOT_COLUMNS))
    end
  end

  def snapshot_rows
    payload = JSON.parse(File.read(Rails.root.join("data", "weapon_skill_effects.json")))
    payload.is_a?(Hash) ? payload.fetch("effects") : payload
  end
end
