class AddTrackableToRaids < ActiveRecord::Migration[8.0]
  def change
    add_column :raids, :trackable, :boolean, default: false, null: false
  end
end
