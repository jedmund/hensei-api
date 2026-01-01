# frozen_string_literal: true

class AddAugmentTypeToWeaponSeries < ActiveRecord::Migration[8.0]
  def up
    add_column :weapon_series, :augment_type, :integer, default: 0, null: false

    # Migrate existing has_ax_skills: true to augment_type: 1 (ax)
    execute <<-SQL.squish
      UPDATE weapon_series
      SET augment_type = 1
      WHERE has_ax_skills = true
    SQL

    remove_column :weapon_series, :has_ax_skills
  end

  def down
    add_column :weapon_series, :has_ax_skills, :boolean, default: false, null: false

    # Migrate augment_type: 1 (ax) back to has_ax_skills: true
    execute <<-SQL.squish
      UPDATE weapon_series
      SET has_ax_skills = true
      WHERE augment_type = 1
    SQL

    remove_column :weapon_series, :augment_type
  end
end
