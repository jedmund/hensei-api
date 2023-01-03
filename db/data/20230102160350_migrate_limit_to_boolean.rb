# frozen_string_literal: true

class MigrateLimitToBoolean < ActiveRecord::Migration[6.1]
  def up
    Weapon.all.each do |weapon|
      if weapon.limit && weapon.limit > 0
        weapon.limit2 = true
      else
        weapon.limit2 = false
      end
    end

    Summon.all.each do |summon|
      if summon.limit && summon.limit > 0
        summon.limit2 = true
      else
        summon.limit2 = false
      end
    end

    def down
      raise ActiveRecord::IrreversibleMigration
    end
  end
