# frozen_string_literal: true

class MigrateAxTypeToAx < ActiveRecord::Migration[6.1]
  def up
    Weapon.all.each do |weapon|
      if weapon.ax_type > 0
        weapon.ax = true
      elsif weapon.ax_type == 0
        weapon.ax = false
        weapon.ax_type = nil
      end

      weapon.save
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
