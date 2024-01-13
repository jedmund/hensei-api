class AddTranscendenceToWeapon < ActiveRecord::Migration[7.0]
  def change
    add_column :weapons, :transcendence, :boolean, default: false
  end
end
