class UpdateTurnCountDefault < ActiveRecord::Migration[7.0]
  def change
    change_column :parties, :turn_count, :integer, null: false, default: 1
  end
end
