class AddClassicIiAndCollabToGacha < ActiveRecord::Migration[8.0]
  def change
    add_column :gacha, :classic_ii, :boolean, default: false
    add_column :gacha, :collab, :boolean, default: false
  end
end
