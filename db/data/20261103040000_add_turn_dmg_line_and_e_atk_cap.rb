# frozen_string_literal: true

# Calculator fixes from a user report (0umD8e): Insignia's turn damage is a demerit
# that stays at 5% per copy (no summon amplification) and gets its own green "Turn DMG"
# panel line; E. ATK caps at 40%.
class AddTurnDmgLineAndEAtkCap < ActiveRecord::Migration[8.0]
  def up
    PanelLine.reset_column_information
    WeaponSkillBoostType.reset_column_information

    GridDamage::PanelPresenter::LINES.each_with_index do |(key, series, label, slug, group), position|
      PanelLine.find_or_initialize_by(boost_type: key, series: series).update!(
        label_en: label, slug: slug, group_name: group, position: position
      )
    end

    WeaponSkillBoostType.where(key: "turn_dmg").update_all(amplifiable: false)
    WeaponSkillBoostType.where(key: "e_atk").update_all(display_cap: 40)
  end

  def down
    PanelLine.where(boost_type: "turn_dmg", series: nil).delete_all
    GridDamage::PanelPresenter::LINES.reject { |line| line.first == "turn_dmg" }
                                     .each_with_index do |(key, series, _label, _slug, _group), position|
      PanelLine.find_by(boost_type: key, series: series)&.update!(position: position)
    end
    WeaponSkillBoostType.where(key: "turn_dmg").update_all(amplifiable: nil)
    WeaponSkillBoostType.where(key: "e_atk").update_all(display_cap: nil)
  end
end
