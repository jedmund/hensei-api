# frozen_string_literal: true

# Removes weapon-skill rows that put boosts on the calculator panel which the
# game doesn't show, restores the Draconic Providence turn-1 EX Might, and adds
# the Rigor and HP (Fixed) panel lines. Found against g0gpOT's in-game panel.
#
# - Main-hand proc skills ("300% Earth damage… (Damage cap: ~400,000)") were
#   parsed into DMG Cap boosts of 100-500%.
# - Athos ("Boost to specs when … 280% or above") was parsed into N.A. Amp. 280.
#   Its real amplification is the N.A. Amp. (Sp.) row, which stays.
# - Draconic Providence s1 imports from the wiki stub carry a junk E. ATK (Prog.)
#   0.1 effect. Judgment of Torrential Tides already has the right row: an EX
#   Might progression datum (+2 at turn 1, SL20). The other five get the same.
# - The generic Godshield row used bonus_des_dmg_ca while the version rows and
#   the panel use bonus_des_ca, so both applied and the line showed twice.
# - β Pendulum's skill hit rate isn't a panel line in game.
class FixCalculatorPhantomBoosts < ActiveRecord::Migration[8.0]
  JUNK_PROVENANCE_NAME = "{{ #vardefineecho%"
  PROVENANCE_PROGRESSION = {
    modifier: "Provenance Progression", boost_type: "atk", series: "ex",
    formula_type: "progression", sl15: 1.5, sl20: 2.0, max_value: 25.0, aura_boostable: false
  }.freeze

  def up
    WeaponSkillEffect.reset_column_information
    WeaponSkillDatum.reset_column_information
    PanelLine.reset_column_information
    WeaponSkillBoostType.reset_column_information

    remove_proc_damage_caps
    remove_athos_threshold_amp
    restore_provenance_progression
    unify_godshield_key
    hide_skill_hit
    sync_panel_lines
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "the removed rows were parser errors"
  end

  private

  def remove_proc_damage_caps
    # No passive skill boosts DMG Cap by 100% or more; these are all proc damage.
    WeaponSkillEffect.where(boost_type: "dmg_cap", manually_edited_at: nil)
                     .where.not(weapon_skill_version_id: nil)
                     .where("value >= 100").delete_all
  end

  def remove_athos_threshold_amp
    WeaponSkillEffect.where(boost_type: "na_amp", value: 280, manually_edited_at: nil)
                     .where("modifier LIKE ?", "% Athos").delete_all
  end

  def restore_provenance_progression
    series = WeaponSeries.find_by(slug: "draconic-providence") or return

    version_ids = WeaponSkillVersion.joins(:skill, weapon_skill: :weapon)
                                    .where(weapons: { weapon_series_id: series.id })
                                    .where("skills.name_en LIKE ?", JUNK_PROVENANCE_NAME)
                                    .pluck(:id)
    WeaponSkillEffect.where(weapon_skill_version_id: version_ids, boost_type: "e_atk_prog",
                            value: 0.1, manually_edited_at: nil).delete_all

    now = Time.current
    version_ids.each do |version_id|
      next if WeaponSkillDatum.exists?(weapon_skill_version_id: version_id,
                                       modifier: PROVENANCE_PROGRESSION[:modifier])

      WeaponSkillDatum.create!(PROVENANCE_PROGRESSION.merge(
                                 weapon_skill_version_id: version_id,
                                 manually_edited_at: now, provenance: "manual"
                               ))
    end
  end

  def unify_godshield_key
    WeaponSkillEffect.where(boost_type: "bonus_des_dmg_ca").update_all(boost_type: "bonus_des_ca")
    WeaponSkillDatum.where(boost_type: "bonus_des_dmg_ca").update_all(boost_type: "bonus_des_ca")

    legacy = WeaponSkillBoostType.find_by(key: "bonus_des_dmg_ca") or return
    if WeaponSkillBoostType.exists?(key: "bonus_des_ca")
      legacy.destroy!
    else
      legacy.update!(key: "bonus_des_ca")
    end
  end

  def hide_skill_hit
    WeaponSkillBoostType.where(key: "skill_hit").update_all(hidden: true)
  end

  def sync_panel_lines
    lines = GridDamage::PanelPresenter::LINES
    keep = lines.map { |(key, series)| [key, series] }
    PanelLine.find_each { |row| row.destroy! unless keep.include?([row.boost_type, row.series]) }

    lines.each_with_index do |(key, series, label, slug, group), position|
      PanelLine.find_or_initialize_by(boost_type: key, series: series).update!(
        label_en: label, slug: slug, group_name: group, position: position
      )
    end
  end
end
