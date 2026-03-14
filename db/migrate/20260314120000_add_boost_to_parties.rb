# frozen_string_literal: true

class AddBoostToParties < ActiveRecord::Migration[7.1]
  def change
    add_column :parties, :boost_mod, :string
    add_column :parties, :boost_side, :string

    add_index :parties, %i[boost_mod boost_side]
  end
end
