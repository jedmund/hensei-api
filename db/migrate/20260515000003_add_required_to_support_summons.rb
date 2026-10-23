class AddRequiredToSupportSummons < ActiveRecord::Migration[8.0]
  def change
    add_column :support_summons, :required, :boolean, null: false, default: false
  end
end
