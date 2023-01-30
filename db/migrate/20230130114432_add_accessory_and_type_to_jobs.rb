class AddAccessoryAndTypeToJobs < ActiveRecord::Migration[7.0]
  def change
    add_column :jobs, :accessory, :boolean, default: false
    add_column :jobs, :accessory_type, :integer, default: 0
  end
end
