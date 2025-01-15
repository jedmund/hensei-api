class AddRecruitsToWeapons < ActiveRecord::Migration[7.0]
  def change
    add_column :weapons, :recruits, :string
  end
end
