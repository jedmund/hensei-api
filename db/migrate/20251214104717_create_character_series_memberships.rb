# frozen_string_literal: true

class CreateCharacterSeriesMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :character_series_memberships, id: :uuid do |t|
      t.uuid :character_id, null: false
      t.uuid :character_series_id, null: false
      t.timestamps
    end

    add_index :character_series_memberships, :character_id
    add_index :character_series_memberships, :character_series_id
    add_index :character_series_memberships, %i[character_id character_series_id],
              unique: true, name: 'idx_char_series_membership_unique'

    add_foreign_key :character_series_memberships, :characters
    add_foreign_key :character_series_memberships, :character_series
  end
end
