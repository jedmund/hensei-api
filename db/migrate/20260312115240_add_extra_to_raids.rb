class AddExtraToRaids < ActiveRecord::Migration[8.0]
  def change
    add_column :raids, :extra, :boolean
  end
end
