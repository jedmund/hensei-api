class AddShowGamertagToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :show_gamertag, :boolean, default: true, null: false
  end
end
