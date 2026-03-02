class AllowNullSeriesOnWeaponSkillData < ActiveRecord::Migration[8.0]
  def change
    change_column_null :weapon_skill_data, :series, true
  end
end
