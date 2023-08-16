class AddColumnsToWeapons < ActiveRecord::Migration[7.0]
  def change
    add_column :weapons, :release_date, :date
    add_column :weapons, :flb_date, :date
    add_column :weapons, :ulb_date, :date

    add_column :weapons, :wiki_en, :string, default: ''
    add_column :weapons, :wiki_ja, :string, default: ''
    add_column :weapons, :gamewith, :string, default: ''
    add_column :weapons, :kamigame, :string, default: ''
  end
end
