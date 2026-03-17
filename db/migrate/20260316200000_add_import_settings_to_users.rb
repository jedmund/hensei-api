# frozen_string_literal: true

class AddImportSettingsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :import_weapons, :boolean, default: true, null: false
    add_column :users, :default_import_visibility, :integer, default: 1, null: false
  end
end
