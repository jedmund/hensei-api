# frozen_string_literal: true

class AddDeletedAtToPhantomPlayers < ActiveRecord::Migration[8.0]
  def change
    add_column :phantom_players, :deleted_at, :datetime
    add_index :phantom_players, :deleted_at
  end
end
