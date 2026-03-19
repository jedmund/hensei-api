class AddWikiRawToBullets < ActiveRecord::Migration[8.0]
  def change
    add_column :bullets, :wiki_raw, :text
  end
end
