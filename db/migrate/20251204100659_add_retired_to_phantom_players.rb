class AddRetiredToPhantomPlayers < ActiveRecord::Migration[8.0]
  def change
    add_column :phantom_players, :retired, :boolean, default: false, null: false
    add_column :phantom_players, :retired_at, :datetime
  end
end
