# frozen_string_literal: true

class RemoveAxFromWeapons < ActiveRecord::Migration[8.0]
  def change
    remove_column :weapons, :ax, :boolean, default: false, null: false
    remove_column :weapons, :ax_type, :integer
  end
end
