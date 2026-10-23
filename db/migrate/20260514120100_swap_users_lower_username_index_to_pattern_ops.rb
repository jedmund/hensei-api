# frozen_string_literal: true

class SwapUsersLowerUsernameIndexToPatternOps < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    add_index :users, 'LOWER(username) text_pattern_ops',
              name: 'index_users_on_lower_username_pattern',
              unique: true,
              algorithm: :concurrently
    remove_index :users, name: 'index_users_on_lower_username', algorithm: :concurrently
    execute 'ALTER INDEX index_users_on_lower_username_pattern RENAME TO index_users_on_lower_username'
  end

  def down
    add_index :users, 'LOWER(username)',
              name: 'index_users_on_lower_username_pattern',
              unique: true,
              algorithm: :concurrently
    remove_index :users, name: 'index_users_on_lower_username', algorithm: :concurrently
    execute 'ALTER INDEX index_users_on_lower_username_pattern RENAME TO index_users_on_lower_username'
  end
end
