# frozen_string_literal: true

class AddManuallyEditedAtToWeaponSkillTables < ActiveRecord::Migration[8.0]
  def change
    add_column :weapon_skill_data, :manually_edited_at, :datetime
    add_column :weapon_skill_effects, :manually_edited_at, :datetime
  end
end
