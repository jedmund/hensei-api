class RenameGameIdToEnemyIdOnRaids < ActiveRecord::Migration[8.0]
  def change
    rename_column :raids, :game_id, :enemy_id
  end
end
