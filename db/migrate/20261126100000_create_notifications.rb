# frozen_string_literal: true

# In-app notifications (GBF-82). One row per thing that happened to a user;
# repeats on the same team (stickers, remixes) bump `count` on the unread row
# for their `group_key` instead of adding rows. `actor_id` is never set for
# stickers, whose givers stay anonymous.
class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications, id: :uuid do |t|
      t.references :recipient, type: :uuid, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.references :actor, type: :uuid, foreign_key: { to_table: :users, on_delete: :nullify }
      t.integer :kind, null: false
      t.string :subject_type, null: false
      t.uuid :subject_id, null: false
      t.string :group_key
      t.integer :count, null: false, default: 1
      t.jsonb :payload, null: false, default: {}
      t.datetime :read_at
      t.timestamps
    end

    add_index :notifications, %i[recipient_id updated_at]
    add_index :notifications, %i[subject_type subject_id]
    add_index :notifications, %i[recipient_id group_key], where: 'read_at IS NULL'

    # When the jewel was last opened: rows updated after it count as new
    add_column :users, :notifications_seen_at, :datetime
  end
end
