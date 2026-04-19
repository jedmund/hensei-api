class AddExtensionVersionTrackingToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :last_extension_version, :string
    add_column :users, :last_extension_version_at, :datetime
  end
end
