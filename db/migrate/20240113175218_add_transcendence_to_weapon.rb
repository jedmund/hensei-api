class AddTranscendenceToWeapon < ActiveRecord::Migration[7.0]
  def change
    add_column :weapons, :transcendence, :boolean, default: false
    add_column :weapons, :transcendence_date, :datetime
  end
end
