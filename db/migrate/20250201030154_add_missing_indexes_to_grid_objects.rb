class AddMissingIndexesToGridObjects < ActiveRecord::Migration[8.0]
  def change
    add_index :parties, :raid_id unless index_exists?(:parties, :raid_id)
    add_index :characters, :granblue_id unless index_exists?(:characters, :granblue_id)
    add_index :summons, :granblue_id unless index_exists?(:summons, :granblue_id)
    add_index :weapons, :granblue_id unless index_exists?(:weapons, :granblue_id)
  end
end
