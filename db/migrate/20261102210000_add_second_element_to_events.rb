# frozen_string_literal: true

# A second boss element, for runs whose bosses share two weaknesses (Records
# of the Ten's Fire and Dark run).
class AddSecondElementToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :second_element, :integer
  end
end
