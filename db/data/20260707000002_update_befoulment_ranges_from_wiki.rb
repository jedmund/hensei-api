# frozen_string_literal: true

# gbf.wiki/Befoulments value table: lvl-1 (base) roll ranges and the exorcision
# reduction step (each of the up-to-4 level-ups reduces by 1x/2x/3x the step).
class UpdateBefoulmentRangesFromWiki < ActiveRecord::Migration[8.0]
  RANGES = {
    'befoul_atk_down' => { base_min: -16.0, base_max: -6.0, reduction_step: 0.3 },
    'befoul_def_down' => { base_min: -33.0, base_max: -13.0, reduction_step: 0.6 },
    'befoul_da_ta_down' => { base_min: -25.0, base_max: -10.0, reduction_step: 0.5 },
    'befoul_ca_dmg_down' => { base_min: -50.0, base_max: -22.0, reduction_step: 1.0 },
    'befoul_ability_dmg_down' => { base_min: -50.0, base_max: -22.0, reduction_step: 1.0 },
    'befoul_hp_down' => { base_min: -50.0, base_max: -22.0, reduction_step: 1.0 },
    'befoul_dot' => { base_min: 6.0, base_max: 16.0, reduction_step: 0.3 },
    'befoul_debuff_down' => { base_min: -16.0, base_max: -6.0, reduction_step: 0.3 }
  }.freeze

  def up
    RANGES.each do |slug, attrs|
      WeaponStatModifier.find_by(slug: slug)&.update!(attrs)
    end
  end

  def down; end
end
