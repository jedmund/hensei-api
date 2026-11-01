# frozen_string_literal: true

# Weapon validates granblue_id uniqueness, but writes that skip validations (bulk
# importers, update_columns) could still create duplicates. Enforce it in the database.
class MakeWeaponGranblueIdUnique < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_index :weapons, :granblue_id, unique: true, algorithm: :concurrently,
                                      name: 'index_weapons_on_granblue_id_unique'
    remove_index :weapons, :granblue_id, name: 'index_weapons_on_granblue_id', algorithm: :concurrently
  end

  def down
    add_index :weapons, :granblue_id, name: 'index_weapons_on_granblue_id', algorithm: :concurrently
    remove_index :weapons, :granblue_id, name: 'index_weapons_on_granblue_id_unique', algorithm: :concurrently
  end
end
