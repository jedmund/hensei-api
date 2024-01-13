class RenameSummonXlbToTranscendence < ActiveRecord::Migration[7.0]
  def change
    rename_column :summons, :xlb, :transcendence
    rename_column :summons, :xlb_date, :transcendence_date
  end
end
