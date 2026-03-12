class AddPlayerCountToRaids < ActiveRecord::Migration[8.0]
  def change
    add_column :raids, :player_count, :integer, default: 18, null: false
  end
end
