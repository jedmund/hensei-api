class AddLocalIdToParties < ActiveRecord::Migration[7.0]
  def change
    add_column :parties, :local_id, :uuid, null: true, unique: true
  end
end
