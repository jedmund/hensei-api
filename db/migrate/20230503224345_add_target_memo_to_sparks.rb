class AddTargetMemoToSparks < ActiveRecord::Migration[7.0]
  def change
    add_column :sparks, :target_memo, :string
  end
end
