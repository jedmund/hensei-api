# frozen_string_literal: true

# Tracks when weapons.wiki_raw was last fetched, so stale weapons (those whose
# latest_date is newer than the last fetch) can be re-fetched selectively.
class AddWikiRawFetchedAtToWeapons < ActiveRecord::Migration[8.0]
  def change
    add_column :weapons, :wiki_raw_fetched_at, :datetime
    add_index :weapons, :wiki_raw_fetched_at
  end
end
