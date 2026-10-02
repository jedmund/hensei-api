# frozen_string_literal: true

# Accounts created with a login provider have no password. Settings suggests
# setting one; this records that the user dismissed the suggestion, so it stays
# dismissed on every device.
class AddPasswordPromptDismissedAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :password_prompt_dismissed_at, :datetime
  end
end
