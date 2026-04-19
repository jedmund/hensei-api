# frozen_string_literal: true

class AddDescriptionToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :description, :string, limit: 140
  end
end
