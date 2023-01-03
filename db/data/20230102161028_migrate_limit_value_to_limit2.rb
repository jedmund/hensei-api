# frozen_string_literal: true

class MigrateLimitValueToLimit2 < ActiveRecord::Migration[6.1]
  def up
    Weapon.all.each do |weapon|
      weapon.limit2 = !(weapon.limit == 0)
      weapon.save
    end

    Summon.all.each do |summon|
      summon.limit2 = !(summon.limit == 0)
      summon.save
    end
  end

  def down
    # raise ActiveRecord::IrreversibleMigration
  end
end
