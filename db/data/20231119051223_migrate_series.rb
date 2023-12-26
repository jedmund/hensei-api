# frozen_string_literal: true

class MigrateSeries < ActiveRecord::Migration[7.0]
  def up
    WeaponKey.find_each do |weapon_key|
      weapon_key.update(new_series: [weapon_key.series])
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
