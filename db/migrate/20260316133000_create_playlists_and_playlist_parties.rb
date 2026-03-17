# frozen_string_literal: true

class CreatePlaylistsAndPlaylistParties < ActiveRecord::Migration[8.0]
  def change
    create_table :playlists, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :video_url
      t.integer :visibility, null: false, default: 1

      t.timestamps
    end

    add_index :playlists, [:user_id, :title], unique: true

    create_table :playlist_parties, id: :uuid do |t|
      t.references :playlist, type: :uuid, null: false, foreign_key: true
      t.references :party, type: :uuid, null: false, foreign_key: true
      t.integer :position

      t.timestamps
    end

    add_index :playlist_parties, [:playlist_id, :party_id], unique: true
  end
end
