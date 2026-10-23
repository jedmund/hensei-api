# frozen_string_literal: true

# Odious Exalto ("25% boost to Taboo <element>'s weapon skills") shows as "<Element> Taboo"
# and adds to the Taboo enhancement, unamplified like the other Exalto boosts; Odious
# stamina has its own "Od Stamina" line. Both from golden XZq7xW.
class AddOdiousExaltoAndOdStaminaLines < ActiveRecord::Migration[8.0]
  def up
    PanelLine.reset_column_information
    WeaponSkillBoostType.reset_column_information

    GridDamage::PanelPresenter::LINES.each_with_index do |(key, series, label, slug, group), position|
      PanelLine.find_or_initialize_by(boost_type: key, series: series).update!(
        label_en: label, slug: slug, group_name: group, position: position
      )
    end

    row = WeaponSkillBoostType.find_or_initialize_by(key: "odious_exalto")
    row.assign_attributes(name_en: "Odious Exalto", category: "utility", amplifiable: false)
    row.save!
  end

  def down
    PanelLine.where(boost_type: "odious_exalto", series: nil).delete_all
    PanelLine.where(boost_type: "stamina", series: "odious").delete_all
    GridDamage::PanelPresenter::LINES
      .reject { |key, series| key == "odious_exalto" || (key == "stamina" && series == "odious") }
      .each_with_index do |(key, series, _label, _slug, _group), position|
        PanelLine.find_by(boost_type: key, series: series)&.update!(position: position)
      end
    WeaponSkillBoostType.where(key: "odious_exalto").delete_all
  end
end
