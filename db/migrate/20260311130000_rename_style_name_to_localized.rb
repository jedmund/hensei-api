# frozen_string_literal: true

class RenameStyleNameToLocalized < ActiveRecord::Migration[7.0]
  def change
    rename_column :characters, :style_name, :style_name_en
    add_column :characters, :style_name_jp, :string
  end
end
