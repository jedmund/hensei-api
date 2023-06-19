class AddRaidGroupToRaids < ActiveRecord::Migration[7.0]
  def change
    add_reference :raids, :group, null: true, to_table: 'raid_groups', type: :uuid
    add_foreign_key :raids, :raid_groups, column: :group_id
  end
end
