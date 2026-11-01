# frozen_string_literal: true

# Awakening validates slug uniqueness (the slug names its icon file), but writes
# that skip validations could still create duplicates. Enforce it in the database.
class MakeAwakeningSlugUnique < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :awakenings, :slug, unique: true, algorithm: :concurrently
  end
end
