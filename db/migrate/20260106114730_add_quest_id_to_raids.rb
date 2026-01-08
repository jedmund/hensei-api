class AddQuestIdToRaids < ActiveRecord::Migration[8.0]
  def change
    add_column :raids, :quest_id, :bigint
  end
end
