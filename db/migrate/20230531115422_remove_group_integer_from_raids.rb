class RemoveGroupIntegerFromRaids < ActiveRecord::Migration[7.0]
  def change
    remove_column :raids, :group, :integer
  end
end
