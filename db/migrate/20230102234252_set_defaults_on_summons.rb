class SetDefaultsOnSummons < ActiveRecord::Migration[6.1]
  def change
    change_column :summons, :flb, :boolean, null: false, default: false
    change_column :summons, :ulb, :boolean, null: false, default: false
    change_column :summons, :max_level, :integer, null: false, default: 100
  end
end
