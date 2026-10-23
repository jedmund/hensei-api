# frozen_string_literal: true

class RenameSupplementalCapScalingKind < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE weapon_skill_effects
      SET scaling_kind = 'supplemental_cap'
      WHERE scaling_kind = 'foe_hp_supplemental'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE weapon_skill_effects
      SET scaling_kind = 'foe_hp_supplemental'
      WHERE scaling_kind = 'supplemental_cap'
    SQL
  end
end
