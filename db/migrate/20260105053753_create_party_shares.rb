# frozen_string_literal: true

class CreatePartyShares < ActiveRecord::Migration[8.0]
  def change
    create_table :party_shares, id: :uuid do |t|
      t.references :party, type: :uuid, null: false, foreign_key: true
      t.references :shareable, type: :uuid, null: false, polymorphic: true
      t.references :shared_by, type: :uuid, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    # Prevent duplicate shares of the same party to the same group
    add_index :party_shares, [:party_id, :shareable_type, :shareable_id],
              unique: true,
              name: 'index_party_shares_unique_per_shareable'

    # Quick lookup of all parties shared with a specific group
    add_index :party_shares, [:shareable_type, :shareable_id]
  end
end
