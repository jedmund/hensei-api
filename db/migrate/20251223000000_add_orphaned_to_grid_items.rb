# frozen_string_literal: true

class AddOrphanedToGridItems < ActiveRecord::Migration[8.0]
  def change
    add_column :grid_weapons, :orphaned, :boolean, default: false, null: false
    add_column :grid_summons, :orphaned, :boolean, default: false, null: false
    add_column :grid_artifacts, :orphaned, :boolean, default: false, null: false

    add_index :grid_weapons, :orphaned
    add_index :grid_summons, :orphaned
    add_index :grid_artifacts, :orphaned
  end
end
