# frozen_string_literal: true

# Yuel (Grand) and Tsukuyomi were recorded as released on 2025-02-27, a day
# before their weapons. They came out with the Legend Festival that started on
# 2025-02-28. Only rows still holding the old date are changed.
class FixYuelTsukuyomiReleaseDate < ActiveRecord::Migration[8.1]
  GRANBLUE_IDS = %w[3040580000 3040581000].freeze

  def up
    Character.where(granblue_id: GRANBLUE_IDS, release_date: Date.new(2025, 2, 27))
             .update_all(release_date: Date.new(2025, 2, 28))
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
