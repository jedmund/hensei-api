# frozen_string_literal: true

# One-time codes the browser extension exchanges for its own tokens after the
# user approves it on the site. Only a SHA-256 digest of each code is stored,
# along with the PKCE challenge the extension sent.
class CreateExtensionAuthCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :extension_auth_codes, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :code_digest, null: false
      t.string :code_challenge, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.timestamps
    end

    add_index :extension_auth_codes, :code_digest, unique: true
    add_index :extension_auth_codes, :expires_at
  end
end
