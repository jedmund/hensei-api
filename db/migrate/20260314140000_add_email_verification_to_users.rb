# frozen_string_literal: true

class AddEmailVerificationToUsers < ActiveRecord::Migration[7.0]
  def up
    add_column :users, :email_verified, :boolean, default: false, null: false
    add_column :users, :email_verification_token_digest, :string
    add_column :users, :email_verification_sent_at, :datetime

    # Existing users predate this feature and are considered verified
    User.update_all(email_verified: true)
  end

  def down
    remove_column :users, :email_verified
    remove_column :users, :email_verification_token_digest
    remove_column :users, :email_verification_sent_at
  end
end
