# frozen_string_literal: true

# Record when each entity's wikitext was fetched, so stored sources can be dated
# and refreshed. weapons.wiki_raw_fetched_at already exists.
class AddWikiFetchDates < ActiveRecord::Migration[8.1]
  def change
    add_column :summons, :wiki_raw_fetched_at, :datetime
    add_column :characters, :wiki_raw_fetched_at, :datetime
    add_column :weapons, :wiki_raw_jp_fetched_at, :datetime
    add_column :summons, :wiki_raw_jp_fetched_at, :datetime
    add_column :characters, :wiki_raw_jp_fetched_at, :datetime
  end
end
