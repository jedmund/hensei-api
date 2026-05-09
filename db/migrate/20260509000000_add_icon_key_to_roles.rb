# frozen_string_literal: true

class AddIconKeyToRoles < ActiveRecord::Migration[8.0]
  def change
    add_column :roles, :icon_key, :string
  end
end
