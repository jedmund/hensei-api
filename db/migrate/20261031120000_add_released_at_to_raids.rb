# frozen_string_literal: true

# When a raid was released, for Home's New battles card (raids from the last 4
# weeks). Nullable: raids without a known date count as not new.
class AddReleasedAtToRaids < ActiveRecord::Migration[8.1]
  def change
    add_column :raids, :released_at, :date
    add_index :raids, :released_at
  end
end
