class AddNicknamesToCharacters < ActiveRecord::Migration[7.0]
  def change
    add_column :characters, :nicknames_en, :string, array: true, default: [], null: false, if_not_exists: true
    add_column :characters, :nicknames_jp, :string, array: true, default: [], null: false, if_not_exists: true
  end
end
