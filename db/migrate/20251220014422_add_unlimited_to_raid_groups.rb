class AddUnlimitedToRaidGroups < ActiveRecord::Migration[8.0]
  def change
    add_column :raid_groups, :unlimited, :boolean, default: false, null: false
  end
end
