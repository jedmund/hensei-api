# frozen_string_literal: true

class AddGameIdToCollectionItems < ActiveRecord::Migration[8.0]
  def change
    # Add game_id to collection_artifacts
    # This stores the unique instance ID from the game's inventory (the "id" field in game data)
    add_column :collection_artifacts, :game_id, :string
    add_index :collection_artifacts, %i[user_id game_id], unique: true, where: 'game_id IS NOT NULL'

    # Add game_id to collection_weapons
    add_column :collection_weapons, :game_id, :string
    add_index :collection_weapons, %i[user_id game_id], unique: true, where: 'game_id IS NOT NULL'

    # Add game_id to collection_summons
    add_column :collection_summons, :game_id, :string
    add_index :collection_summons, %i[user_id game_id], unique: true, where: 'game_id IS NOT NULL'
  end
end
