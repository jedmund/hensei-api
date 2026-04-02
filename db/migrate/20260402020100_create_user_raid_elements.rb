class CreateUserRaidElements < ActiveRecord::Migration[8.0]
  def change
    create_table :user_raid_elements, id: :uuid do |t|
      t.uuid :user_id, null: false
      t.uuid :raid_id, null: false
      t.integer :element, null: false
      t.timestamps
    end

    add_foreign_key :user_raid_elements, :users
    add_foreign_key :user_raid_elements, :raids
    add_index :user_raid_elements, [:user_id, :raid_id, :element], unique: true, name: 'index_user_raid_elements_unique'
    add_index :user_raid_elements, :raid_id
  end
end
