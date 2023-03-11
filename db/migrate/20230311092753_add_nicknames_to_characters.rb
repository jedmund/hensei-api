class AddNicknamesToCharacters < ActiveRecord::Migration[7.0]
  def change
    add_column :characters, :nicknames_en, :string, array: true, default: [], null: false
    add_column :characters, :nicknames_jp, :string, array: true, default: [], null: false
  end
end
