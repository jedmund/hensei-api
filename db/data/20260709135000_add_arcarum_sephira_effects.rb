# frozen_string_literal: true

class AddArcarumSephiraEffects < ActiveRecord::Migration[8.0]
  CONDITION = { "type" => "arcarum", "eq" => true }.freeze

  ROWS = [
    ["Sephira Manus", "da", 54.0,
     "Wilhelm Militis with Arcarum ON/OFF shows DA 60% vs 6%; this row is the +54% Arcarum delta."],
    ["Sephira Manus", "ta", 54.0,
     "Wilhelm Militis with Arcarum ON/OFF shows TA 60% vs 6%; this row is the +54% Arcarum delta."],
    ["Sephira Salire", "na_dmg_cap", 7.0,
     "Koukouvagia Militis with Arcarum ON/OFF shows N.A. DMG Cap 10% vs 3%; this row is the +7% Arcarum delta."]
  ].freeze

  def up
    WeaponSkillEffect.reset_column_information

    ROWS.each do |modifier, boost_type, value, notes|
      effect = WeaponSkillEffect.where(
        modifier: modifier,
        boost_type: boost_type,
        scaling_kind: "conditional_flat",
        weapon_skill_version_id: nil,
        key_slug: nil,
        condition: CONDITION
      ).first_or_initialize

      effect.assign_attributes(
        value: value,
        value_unit: "percent",
        aura_boostable: false,
        seraphic_affected: false,
        stacking: "additive",
        applies_to: "element_allies",
        battle_interaction: false,
        depends_on: ["arcarum"],
        notes: notes
      )
      effect.save!
    end
  end

  def down
    ROWS.each do |modifier, boost_type, _value, _notes|
      WeaponSkillEffect.where(
        modifier: modifier,
        boost_type: boost_type,
        scaling_kind: "conditional_flat",
        weapon_skill_version_id: nil,
        key_slug: nil,
        condition: CONDITION
      ).delete_all
    end
  end
end
