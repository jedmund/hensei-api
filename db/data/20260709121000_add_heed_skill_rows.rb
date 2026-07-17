# frozen_string_literal: true

class AddHeedSkillRows < ActiveRecord::Migration[8.0]
  def up
    WeaponSkillDatum.reset_column_information
    WeaponSkillEffect.reset_column_information

    datum = WeaponSkillDatum.find_or_initialize_by(
      modifier: "Heed",
      boost_type: "da",
      series: "normal_omega",
      size: "small",
      weapon_skill_version_id: nil
    )
    datum.assign_attributes(
      formula_type: "flat",
      sl1: nil,
      sl10: 2.5,
      sl15: 3.5,
      sl20: nil,
      sl25: nil,
      coefficient: nil,
      max_value: nil,
      aura_boostable: true
    )
    datum.save!

    effect = WeaponSkillEffect.where(
      modifier: "Heed",
      boost_type: "counter_dmg",
      scaling_kind: "static",
      weapon_skill_version_id: nil,
      key_slug: nil,
      condition: {}
    ).first_or_initialize
    effect.assign_attributes(
      value: 3.0,
      value_unit: "percent",
      aura_boostable: false,
      seraphic_affected: false,
      stacking: "additive",
      applies_to: "element_allies",
      battle_interaction: false,
      notes: "White Hawk SL10 Varuna/Varuna, Phantasmas SL15 Hades/Hades, and Abyss Striker SL15 Celeste/Celeste show Counter Rate 3%; not summon-aura amplified."
    )
    effect.save!
  end

  def down
    WeaponSkillDatum.where(
      modifier: "Heed",
      boost_type: "da",
      series: "normal_omega",
      size: "small",
      weapon_skill_version_id: nil
    ).delete_all

    WeaponSkillEffect.where(
      modifier: "Heed",
      boost_type: "counter_dmg",
      scaling_kind: "static",
      weapon_skill_version_id: nil,
      key_slug: nil,
      condition: {}
    ).delete_all
  end
end
