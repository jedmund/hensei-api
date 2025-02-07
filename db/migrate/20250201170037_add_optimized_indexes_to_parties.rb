class AddOptimizedIndexesToParties < ActiveRecord::Migration[8.0]
  def change
    # Add composite index for grid positions since we order by these
    add_index :grid_weapons, [:party_id, :position], name: 'index_grid_weapons_on_party_id_and_position'
    add_index :grid_characters, [:party_id, :position], name: 'index_grid_characters_on_party_id_and_position'
    add_index :grid_summons, [:party_id, :position], name: 'index_grid_summons_on_party_id_and_position'
  end
end
