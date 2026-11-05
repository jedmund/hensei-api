# frozen_string_literal: true

# Append-only log of changes to a user's access, made by admins from the
# Database (role changes; feature grants later). Both user links are cleared
# rather than blocking account deletion.
class CreateUserAccessChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :user_access_changes, id: :uuid do |t|
      t.references :user, type: :uuid, foreign_key: { on_delete: :nullify }, index: false
      t.references :actor, type: :uuid, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :kind, null: false
      t.integer :from_role
      t.integer :to_role
      t.datetime :created_at, null: false
    end

    add_index :user_access_changes, %i[user_id created_at]
  end
end
