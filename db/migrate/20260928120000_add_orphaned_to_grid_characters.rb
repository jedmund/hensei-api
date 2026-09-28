# frozen_string_literal: true

# Grid weapons, summons and artifacts are marked orphaned when their collection item is
# deleted; grid characters had no column for it, so deleting a collection character
# that was used in a party failed the foreign key. The web already renders the flag.
class AddOrphanedToGridCharacters < ActiveRecord::Migration[8.0]
  def change
    add_column :grid_characters, :orphaned, :boolean, default: false, null: false
    add_index :grid_characters, :orphaned
  end
end
