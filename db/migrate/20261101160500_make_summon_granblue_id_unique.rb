# frozen_string_literal: true

# Summon validates granblue_id uniqueness, but writes that skip validations (bulk
# importers, update_columns) could still create duplicates. Enforce it in the database.
class MakeSummonGranblueIdUnique < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_index :summons, :granblue_id, unique: true, algorithm: :concurrently,
                                      name: 'index_summons_on_granblue_id_unique'
    remove_index :summons, :granblue_id, name: 'index_summons_on_granblue_id', algorithm: :concurrently
  end

  def down
    add_index :summons, :granblue_id, name: 'index_summons_on_granblue_id', algorithm: :concurrently
    remove_index :summons, :granblue_id, name: 'index_summons_on_granblue_id_unique', algorithm: :concurrently
  end
end
