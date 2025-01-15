class RemoveRecruitsIdFromWeapons < ActiveRecord::Migration[7.0]
  def change
    remove_column :weapons, :recruits_id, :uuid
    remove_index :weapons, :recruits_id if index_exists?(:weapons, :recruits_id)
  end
end
