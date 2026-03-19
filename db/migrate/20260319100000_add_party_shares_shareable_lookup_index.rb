# frozen_string_literal: true

class AddPartySharesShareableLookupIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :party_shares, [:shareable_type, :shareable_id, :party_id],
              name: 'idx_party_shares_shareable_lookup',
              algorithm: :concurrently
  end
end
