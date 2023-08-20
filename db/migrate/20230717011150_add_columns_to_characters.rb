class AddColumnsToCharacters < ActiveRecord::Migration[7.0]
  def change
    add_column :characters, :release_date, :date
    add_column :characters, :flb_date, :date
    add_column :characters, :ulb_date, :date

    add_column :characters, :wiki_ja, :string, null: false, default: ''
    add_column :characters, :gamewith, :string, null: false, default: ''
    add_column :characters, :kamigame, :string, null: false, default: ''
  end
end
