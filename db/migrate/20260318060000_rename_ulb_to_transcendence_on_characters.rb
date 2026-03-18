class RenameUlbToTranscendenceOnCharacters < ActiveRecord::Migration[8.0]
  def change
    rename_column :characters, :ulb, :transcendence
    rename_column :characters, :ulb_date, :transcendence_date
    rename_column :characters, :max_hp_ulb, :max_hp_transcendence
    rename_column :characters, :max_atk_ulb, :max_atk_transcendence
  end
end
