class AddGameIdToRaids < ActiveRecord::Migration[8.0]
  def change
    add_column :raids, :game_id, :integer
  end
end
