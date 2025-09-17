class DropGameRawEnBackup < ActiveRecord::Migration[8.0]
  def change
    remove_column :characters, :game_raw_en_backup
    remove_column :summons, :game_raw_en_backup
    remove_column :weapons, :game_raw_en_backup
  end
end
