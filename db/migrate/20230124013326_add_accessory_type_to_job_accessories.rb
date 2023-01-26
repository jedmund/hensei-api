class AddAccessoryTypeToJobAccessories < ActiveRecord::Migration[7.0]
  def change
    add_column :job_accessories, :accessory_type, :integer
  end
end
