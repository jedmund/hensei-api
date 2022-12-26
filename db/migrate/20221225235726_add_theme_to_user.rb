class AddThemeToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :theme, :string
  end
end
