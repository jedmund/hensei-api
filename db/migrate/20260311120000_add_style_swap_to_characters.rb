# frozen_string_literal: true

class AddStyleSwapToCharacters < ActiveRecord::Migration[8.0]
  def change
    add_column :characters, :style_swap, :boolean, default: false, null: false
    add_column :characters, :style_name, :string
  end
end
