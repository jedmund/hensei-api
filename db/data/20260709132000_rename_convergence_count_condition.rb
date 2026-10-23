# frozen_string_literal: true

class RenameConvergenceCountCondition < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE weapon_skill_effects
      SET condition = jsonb_set(condition, '{type}', '"same_weapon_type_count"', false)
      WHERE modifier = 'Convergence'
        AND condition ->> 'type' = 'weapon_group_count'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE weapon_skill_effects
      SET condition = jsonb_set(condition, '{type}', '"weapon_group_count"', false)
      WHERE modifier = 'Convergence'
        AND condition ->> 'type' = 'same_weapon_type_count'
    SQL
  end
end
