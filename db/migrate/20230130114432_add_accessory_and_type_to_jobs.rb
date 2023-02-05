class AddAccessoryAndTypeToJobs < ActiveRecord::Migration[7.0]
  def change
    add_column :jobs, :accessory, :boolean, default: false unless column_exists?(:jobs, :accessory)
    add_column :jobs, :accessory_type, :integer, default: 0 unless column_exists?(:jobs, :accessory_type)
  end
end
