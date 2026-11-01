# frozen_string_literal: true

# Catalogue tables get created_at/updated_at so admin collections (GBF-138)
# can show, filter and sort by edit time and key their ETags on it. Existing
# rows get the migration time; the database default keeps raw-SQL writers
# working. Bulk writers (update_all, upsert_all, raw SQL) must still set
# updated_at themselves, or ETags go stale.
class AddTimestampsToCatalogueTables < ActiveRecord::Migration[8.1]
  TABLES = %i[
    characters character_series summons summon_series jobs job_skills job_accessories
    weapon_series weapon_keys weapon_key_series awakenings weapon_awakenings
    raids raid_groups artifacts artifact_skills
  ].freeze

  # Sorted in admin list views.
  INDEXED = %i[characters summons jobs character_series summon_series weapon_series weapon_key_series raids].freeze

  def change
    TABLES.each do |table|
      add_timestamps table, null: false, default: -> { 'CURRENT_TIMESTAMP' }
    end
    INDEXED.each { |table| add_index table, :updated_at }

    # guidebooks already has created_at.
    add_column :guidebooks, :updated_at, :datetime, null: false, default: -> { 'CURRENT_TIMESTAMP' }
    up_only { execute 'UPDATE guidebooks SET updated_at = created_at' }
  end
end
