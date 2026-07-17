# frozen_string_literal: true

class MarkMarvelPanelClosed < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE weapon_skill_effects
      SET value_unit = NULL,
          depends_on = ARRAY['hp_percent']::varchar[],
          notes = 'Cap 50k-150k scales from water allies'' current HP and is validated by Wilhelm Militis HP sweep. Raw damage-strength modeling is out of scope for the boost panel.'
      WHERE modifier = 'Marvel'
        AND boost_type = 'skill_dmg_supp'
        AND scaling_kind = 'supplemental_cap'
        AND weapon_skill_version_id IS NULL
        AND key_slug IS NULL
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE weapon_skill_effects
      SET value_unit = 'percent_foe_max_hp',
          depends_on = ARRAY['foe_max_hp', 'hp_percent']::varchar[],
          notes = 'VERIFY: supplemental strength % not stated in prose; cap 50k-150k by HP.'
      WHERE modifier = 'Marvel'
        AND boost_type = 'skill_dmg_supp'
        AND scaling_kind = 'supplemental_cap'
        AND weapon_skill_version_id IS NULL
        AND key_slug IS NULL
    SQL
  end
end
