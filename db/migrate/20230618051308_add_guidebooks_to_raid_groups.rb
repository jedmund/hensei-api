class AddGuidebooksToRaidGroups < ActiveRecord::Migration[7.0]
  def change
    add_column :raid_groups, :guidebooks, :boolean, default: false, null: false
  end
end
