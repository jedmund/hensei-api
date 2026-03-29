# frozen_string_literal: true

class AddSimplePortraitsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :simple_portraits, :boolean, default: false, null: false
  end
end
