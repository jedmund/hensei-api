class AddNewPartyDetails < ActiveRecord::Migration[7.0]
  def change
    add_column :parties, :full_auto, :boolean, default: false, null: false
    add_column :parties, :auto_guard, :boolean, default: false, null: false
    add_column :parties, :charge_attack, :boolean, default: false, null: false

    add_column :parties, :clear_time, :integer, default: 0, null: false
    add_column :parties, :button_count, :integer, default: 0, null: false
    add_column :parties, :chain_count, :integer, default: 0, null: false
    add_column :parties, :turn_count, :integer, default: 0, null: false
  end
end
