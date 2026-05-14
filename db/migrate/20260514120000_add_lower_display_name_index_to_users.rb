# frozen_string_literal: true

class AddLowerDisplayNameIndexToUsers < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :users, 'LOWER(display_name) text_pattern_ops',
              name: 'index_users_on_lower_display_name',
              algorithm: :concurrently
  end
end
