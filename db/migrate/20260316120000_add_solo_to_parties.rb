# frozen_string_literal: true

class AddSoloToParties < ActiveRecord::Migration[8.0]
  def change
    add_column :parties, :solo, :boolean, default: false, null: false
  end
end
