class AddTranscendenceLevelToGridWeapon < ActiveRecord::Migration[7.0]
  def change
    add_column :grid_weapons, :transcendence_step, :integer, default: 0
  end
end
