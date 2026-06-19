# frozen_string_literal: true

class CreateSubstitutions < ActiveRecord::Migration[8.0]
  def change
    create_table :substitutions, id: :uuid do |t|
      t.references :grid, polymorphic: true, type: :uuid, null: false
      t.references :substitute_grid, polymorphic: true, type: :uuid, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :substitutions,
              %i[grid_type grid_id substitute_grid_type substitute_grid_id],
              unique: true,
              name: 'index_substitutions_uniqueness'
  end
end
