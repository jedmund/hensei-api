class AddWikiRawToCharacters < ActiveRecord::Migration[8.0]
  def change
    add_column :characters, :wiki_raw, :text
    add_column :characters, :game_raw_en, :text
    add_column :characters, :game_raw_jp, :text
  end
end
