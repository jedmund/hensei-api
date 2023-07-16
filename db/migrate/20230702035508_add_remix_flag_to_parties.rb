class AddRemixFlagToParties < ActiveRecord::Migration[7.0]
  def change
    add_column :parties, :remix, :boolean, default: false, null: false
  end
end
