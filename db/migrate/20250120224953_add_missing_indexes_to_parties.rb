class AddMissingIndexesToParties < ActiveRecord::Migration[8.0]
  def change
    add_index :parties, :visibility
    add_index :parties, :element
    add_index :parties, :created_at
    add_index :parties, [:weapons_count, :characters_count, :summons_count],
              name: 'index_parties_on_counters'
    add_index :parties, [:visibility, :created_at],
              name: 'index_parties_on_visibility_created_at'
    add_index :parties, :shortcode
  end
end
