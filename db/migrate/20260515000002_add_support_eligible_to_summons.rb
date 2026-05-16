class AddSupportEligibleToSummons < ActiveRecord::Migration[8.0]
  def change
    add_column :summons, :support_eligible, :boolean, default: true, null: false
  end
end
