class AddNewAwakeningTypeToGridWeapons < ActiveRecord::Migration[7.0]
  def change
    # Add a reference on grid_weapons to the awakenings table, which has a uuid id
    add_reference :grid_weapons, :awakening, type: :uuid, foreign_key: { to_table: :awakenings }
  end
end
