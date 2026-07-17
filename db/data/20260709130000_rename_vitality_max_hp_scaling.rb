# frozen_string_literal: true

class RenameVitalityMaxHpScaling < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE weapon_skill_effects
      SET scaling_kind = 'ally_max_hp_scaled'
      WHERE modifier = 'Vitality'
        AND scaling_kind = 'ally_hp_scaled'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE weapon_skill_effects
      SET scaling_kind = 'ally_hp_scaled'
      WHERE modifier = 'Vitality'
        AND scaling_kind = 'ally_max_hp_scaled'
    SQL
  end
end
