# frozen_string_literal: true

class AllowNullSizeOnWeaponSkillData < ActiveRecord::Migration[8.0]
  def up
    # Shape-B skills (Ars/Ultio EX combos) have no size dimension — their rows are
    # keyed by (modifier, boost_type, series) with a null size.
    change_column_null :weapon_skill_data, :size, true
  end

  def down
    change_column_null :weapon_skill_data, :size, false
  end
end
