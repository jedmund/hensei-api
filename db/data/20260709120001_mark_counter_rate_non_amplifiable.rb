# frozen_string_literal: true

class MarkCounterRateNonAmplifiable < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE weapon_skill_boost_types
      SET amplifiable = FALSE
      WHERE key = 'counter_dmg'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE weapon_skill_boost_types
      SET amplifiable = NULL
      WHERE key = 'counter_dmg'
    SQL
  end
end
