# frozen_string_literal: true

class AddBefoulmentPermeation < ActiveRecord::Migration[8.0]
  def change
    # The smallest exorcision reduction roll (each level reduces the befoulment by
    # 1x, 2x, or 3x this amount — gbf.wiki/Befoulments).
    add_column :weapon_stat_modifiers, :reduction_step, :float

    # Permeation: the game's integer gauge of how befouled the weapon rolled from the
    # start, unaffected by exorcision. befoulment_strength stores the CURRENT
    # (post-exorcision) percentage value the game displays.
    add_column :grid_weapons, :befoulment_permeation, :integer
    add_column :collection_weapons, :befoulment_permeation, :integer
  end
end
