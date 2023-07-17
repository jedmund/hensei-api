class AddGbfWikiToCharacter < ActiveRecord::Migration[7.0]
  def change
    add_column :characters, :wiki_en, :string, null: false, default: ''
  end
end
