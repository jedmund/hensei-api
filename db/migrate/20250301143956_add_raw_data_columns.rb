class AddRawDataColumns < ActiveRecord::Migration[8.0]
  def change
    add_column :characters, :wiki_raw, :text
    add_column :characters, :game_raw_en, :text
    add_column :characters, :game_raw_jp, :text

    add_column :summons, :wiki_raw, :text
    add_column :summons, :game_raw_en, :text
    add_column :summons, :game_raw_jp, :text

    add_column :weapons, :wiki_raw, :text
    add_column :weapons, :game_raw_en, :text
    add_column :weapons, :game_raw_jp, :text
  end
end
