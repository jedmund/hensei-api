# frozen_string_literal: true

# Links a user to a login provider (Discord, Google, Apple) by the provider's
# stable user ID. Provider access and refresh tokens are never stored.
class CreateUserIdentities < ActiveRecord::Migration[8.0]
  def change
    create_table :user_identities, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: false
      t.string :provider, null: false
      t.string :provider_uid, null: false
      t.string :email
      t.boolean :email_verified, default: false, null: false
      t.boolean :is_private_email, default: false, null: false
      t.datetime :last_used_at
      t.timestamps
    end

    add_index :user_identities, %i[provider provider_uid], unique: true
    add_index :user_identities, %i[user_id provider], unique: true
  end
end
