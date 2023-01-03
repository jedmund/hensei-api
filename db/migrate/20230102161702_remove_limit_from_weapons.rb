class RemoveLimitFromWeapons < ActiveRecord::Migration[6.1]
  def change
    remove_column :weapons, :limit, :integer
  end
end
