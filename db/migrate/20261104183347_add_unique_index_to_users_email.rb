# frozen_string_literal: true

# Emails were only unique by validation, which a concurrent signup can slip past.
# Stored emails are already lowercase and trimmed (User normalizes them), and
# production had no duplicates when this was written, so the index builds as is.
class AddUniqueIndexToUsersEmail < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :users, :email, unique: true, algorithm: :concurrently
  end
end
