class ChangeLimitToBoolean < ActiveRecord::Migration[6.1]
  def change
    add_column :weapons, :limit2, :boolean, default: false, null: false
    add_column :summons, :limit2, :boolean, default: false, null: false
  end
end
