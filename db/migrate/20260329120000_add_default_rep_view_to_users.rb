# frozen_string_literal: true

class AddDefaultRepViewToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :default_rep_view, :string, default: 'weapons', null: false
  end
end
