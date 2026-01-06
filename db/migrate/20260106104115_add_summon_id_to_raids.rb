class AddSummonIdToRaids < ActiveRecord::Migration[8.0]
  def change
    add_column :raids, :summon_id, :bigint
  end
end
