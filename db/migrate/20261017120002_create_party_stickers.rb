# frozen_string_literal: true

# One sticker per user per party. Changing a sticker updates the row, so the
# unique (user_id, party_id) index is what enforces the rule.
class CreatePartyStickers < ActiveRecord::Migration[8.1]
  def change
    create_table :party_stickers, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: false
      t.references :party, type: :uuid, null: false, foreign_key: true, index: false
      t.references :sticker, type: :uuid, null: false, foreign_key: true

      t.timestamps
    end

    add_index :party_stickers, %i[user_id party_id], unique: true
    add_index :party_stickers, %i[party_id sticker_id]
    add_index :party_stickers, :created_at
  end
end
