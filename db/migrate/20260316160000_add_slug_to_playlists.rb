# frozen_string_literal: true

class AddSlugToPlaylists < ActiveRecord::Migration[8.0]
  def change
    add_column :playlists, :slug, :string, null: false, default: ''
    add_index :playlists, %i[user_id slug], unique: true

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE playlists
          SET slug = LOWER(REPLACE(REPLACE(TRIM(title), ' ', '-'), '''', ''))
        SQL
      end
    end
  end
end
