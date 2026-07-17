# frozen_string_literal: true

class AddUnboostableCruxSkillRow < ActiveRecord::Migration[8.0]
  def up
    WeaponSkillDatum.reset_column_information

    datum = WeaponSkillDatum.find_or_initialize_by(
      modifier: "Crux",
      boost_type: "ca_supp",
      series: "ex",
      size: "big",
      weapon_skill_version_id: nil
    )
    datum.assign_attributes(
      formula_type: "flat",
      sl1: 400_000.0,
      sl10: 400_000.0,
      sl15: 400_000.0,
      sl20: 400_000.0,
      sl25: nil,
      coefficient: nil,
      max_value: nil,
      aura_boostable: false,
      provenance: "panel_capture"
    )
    datum.save!
  end

  def down
    WeaponSkillDatum.where(
      modifier: "Crux",
      boost_type: "ca_supp",
      series: "ex",
      size: "big",
      weapon_skill_version_id: nil
    ).delete_all
  end
end
