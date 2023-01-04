class UpdateNullableOnPartyDetails < ActiveRecord::Migration[7.0]
  def change
    change_column :parties, :button_count, :integer, null: true, default: nil
    change_column :parties, :chain_count, :integer, null: true, default: nil
    change_column :parties, :turn_count, :integer, null: true, default: nil
  end
end
