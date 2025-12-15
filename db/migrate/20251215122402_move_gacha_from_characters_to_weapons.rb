# frozen_string_literal: true

class MoveGachaFromCharactersToWeapons < ActiveRecord::Migration[8.0]
  def change
    # Add gacha boolean to weapons table
    add_column :weapons, :gacha, :boolean, default: false, null: false
    add_index :weapons, :gacha

    # Remove gacha_available from characters table
    remove_index :characters, :gacha_available
    remove_column :characters, :gacha_available, :boolean, default: true, null: false
  end
end
