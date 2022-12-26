class SetDefaultValueToTheme < ActiveRecord::Migration[6.1]
  def change
    change_column :users, :theme, :string, null: false, default: 'system'
  end
end
