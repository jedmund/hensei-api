class AddIndexToWeaponRecruits < ActiveRecord::Migration[7.0]
  def change
    add_index :weapons, :recruits
  end
end
