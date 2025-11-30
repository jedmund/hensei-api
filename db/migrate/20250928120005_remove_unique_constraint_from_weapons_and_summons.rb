class RemoveUniqueConstraintFromWeaponsAndSummons < ActiveRecord::Migration[8.0]
  def change
    # Remove unique indexes for collection_weapons
    remove_index :collection_weapons, [:user_id, :weapon_id]
    add_index :collection_weapons, [:user_id, :weapon_id]

    # Remove unique indexes for collection_summons
    remove_index :collection_summons, [:user_id, :summon_id]
    add_index :collection_summons, [:user_id, :summon_id]
  end
end