class AddColumnsToSummons < ActiveRecord::Migration[7.0]
  def change
    add_column :summons, :summon_id, :integer
    add_column :summons, :release_date, :date
    add_column :summons, :flb_date, :date
    add_column :summons, :ulb_date, :date

    add_column :summons, :wiki_en, :string, default: ''
    add_column :summons, :wiki_ja, :string, default: ''
    add_column :summons, :gamewith, :string, default: ''
    add_column :summons, :kamigame, :string, default: ''
  end
end
