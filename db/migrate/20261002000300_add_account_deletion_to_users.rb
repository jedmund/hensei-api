# frozen_string_literal: true

# Self-serve account deletion. A request schedules the account for deletion
# 30 days out; a daily job purges accounts whose date has passed. Records that
# belong to a crew or to the difficulty audit trail outlive the account that
# created them, so their user columns become nullable and are cleared on purge.
class AddAccountDeletionToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :deletion_scheduled_at, :datetime
    add_index :users, :deletion_scheduled_at, where: 'deletion_scheduled_at IS NOT NULL'

    change_column_null :crew_rosters, :created_by_id, true
    change_column_null :gw_individual_scores, :recorded_by_id, true
    change_column_null :difficulty_change_logs, :user_id, true
  end
end
