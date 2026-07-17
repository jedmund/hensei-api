# frozen_string_literal: true

# The wiki's AX_Skills page defines the real model: a secondary AX skill is drawn
# from a 4-option pool keyed by (weapon series type, chosen primary), and primary/
# secondary rolls of the same skill have DIFFERENT value ranges (base_min/max are
# the primary ranges; secondary_min/max the secondary ones).
class AxPoolsAndRanges < ActiveRecord::Migration[8.0]
  def change
    change_table :weapon_stat_modifiers, bulk: true do |t|
      t.decimal :secondary_min, precision: 8, scale: 2
      t.decimal :secondary_max, precision: 8, scale: 2
      t.jsonb :ax_secondaries, default: {}, null: false # on primaries: {"standard"=>[slugs], "xeno"=>[slugs]}
    end
  end
end
