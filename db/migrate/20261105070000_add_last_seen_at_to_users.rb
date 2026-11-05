# frozen_string_literal: true

# When a signed-in user last used the Service, to within a few minutes
# (Api::V1::ApiController#record_activity). Admins see and sort by it in the
# Database's Users section.
class AddLastSeenAtToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :users, :last_seen_at, :datetime
    add_index :users, :last_seen_at, algorithm: :concurrently
  end
end
