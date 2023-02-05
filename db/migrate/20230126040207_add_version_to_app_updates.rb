class AddVersionToAppUpdates < ActiveRecord::Migration[7.0]
  def change
    add_column :app_updates, :version, :string
  end
end
