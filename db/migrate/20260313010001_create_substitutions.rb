class CreateSubstitutions < ActiveRecord::Migration[8.0]
  def change
    create_table :substitutions, id: :uuid do |t|
      t.string :grid_type, null: false
      t.uuid :grid_id, null: false
      t.string :substitute_grid_type, null: false
      t.uuid :substitute_grid_id, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :substitutions, %i[grid_type grid_id]
    add_index :substitutions, %i[grid_type grid_id position], unique: true
    add_index :substitutions, %i[substitute_grid_type substitute_grid_id]
  end
end
