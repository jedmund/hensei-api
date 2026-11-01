# frozen_string_literal: true

# Raids are looked up by slug (their URLs) and Raid validates it unique;
# enforce that in the database too.
class MakeRaidSlugUnique < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :raids, :slug, unique: true, algorithm: :concurrently
  end
end
