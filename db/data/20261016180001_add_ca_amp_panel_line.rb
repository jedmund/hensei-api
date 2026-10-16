# frozen_string_literal: true

# The plain C.A. Amp. line, apart from C.A. Amp. (Sp.): Sephirath Eparc II's C.A.
# amplification shows there in game (golden 0ZA6Ak). C.B. DMG shows capped at 120,
# like C.A. DMG (0ZA6Ak: orange at 120).
class AddCaAmpPanelLine < ActiveRecord::Migration[8.0]
  def up
    PanelLine.reset_column_information
    WeaponSkillBoostType.reset_column_information

    GridDamage::PanelPresenter::LINES.each_with_index do |(key, series, label, slug, group), position|
      PanelLine.find_or_initialize_by(boost_type: key, series: series).update!(
        label_en: label, slug: slug, group_name: group, position: position
      )
    end

    row = WeaponSkillBoostType.find_or_initialize_by(key: "ca_amp")
    row.assign_attributes(name_en: "C.A. Amp.", category: "offensive")
    row.save!
    WeaponSkillBoostType.where(key: "cb_dmg").update_all(display_cap: 120)
  end

  def down
    PanelLine.where(boost_type: "ca_amp", series: nil).delete_all
    GridDamage::PanelPresenter::LINES.reject { |line| line.first == "ca_amp" }
                                     .each_with_index do |(key, series, _label, _slug, _group), position|
      PanelLine.find_by(boost_type: key, series: series)&.update!(position: position)
    end
    WeaponSkillBoostType.where(key: "ca_amp").delete_all
    WeaponSkillBoostType.where(key: "cb_dmg").update_all(display_cap: nil)
  end
end
