class AddHlToRaidGroups < ActiveRecord::Migration[7.0]
  def change
    add_column :raid_groups, :hl, :boolean, default: true, null: false
  end
end
