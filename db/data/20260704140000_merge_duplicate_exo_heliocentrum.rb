# frozen_string_literal: true

# Exo Heliocentrum exists twice under granblue_id 1040424300. The keeper
# (d7c0cf3d) carries the weapon_awakenings links and ~95% of usage (14 grids,
# 356 collection rows) but a NULL max_awakening_level; the duplicate (3639d531)
# has max_awakening_level 10 and light usage (1 grid, 24 collection rows).
# Copy the max level onto the keeper, repoint every reference, delete the dup.
#
# collection_weapons (user_id, weapon_id) is intentionally non-unique (players
# own multiple copies) and no (user_id, game_id) pairs collide across the two
# rows, so repointing cannot violate constraints.
class MergeDuplicateExoHeliocentrum < ActiveRecord::Migration[8.0]
  KEEPER = "d7c0cf3d-7652-48a1-831b-4bd5b6448e1d"
  DUPLICATE = "3639d531-05fb-4402-8c00-8542c5de410e"

  def up
    return unless duplicate_exists?

    execute <<~SQL
      UPDATE weapons k
      SET max_awakening_level = d.max_awakening_level
      FROM weapons d
      WHERE k.id = '#{KEEPER}' AND d.id = '#{DUPLICATE}'
        AND k.max_awakening_level IS NULL
    SQL

    %w[grid_weapons collection_weapons weapon_awakenings].each do |table|
      execute "UPDATE #{table} SET weapon_id = '#{KEEPER}' WHERE weapon_id = '#{DUPLICATE}'"
    end

    execute "DELETE FROM weapons WHERE id = '#{DUPLICATE}'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def duplicate_exists?
    select_value("SELECT 1 FROM weapons WHERE id = '#{DUPLICATE}'").present?
  end
end
