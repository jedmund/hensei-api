class RemoveLimitFromSummons < ActiveRecord::Migration[6.1]
  def change
    remove_column :summons, :limit, :integer
  end
end
