class AddCollectionPrivacyToUsers < ActiveRecord::Migration[8.0]
  def change
    # Privacy levels: 0 = public, 1 = crew_only, 2 = private
    add_column :users, :collection_privacy, :integer, default: 0, null: false
    add_index :users, :collection_privacy
  end
end