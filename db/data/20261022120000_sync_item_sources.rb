# frozen_string_literal: true

# Ran once on the deploy after PR 7b (as Granblue::ItemSourceSync): stored into `sources` what
# the previous code wrote to the old weapon and summon columns and to weapon_sources after the
# 7b copy migrations ran, and recorded the run (ar_internal_metadata item_sources_synced_at),
# which the column drop (20261023100000) checks.
#
# The sync class is gone with the columns. On a database that runs this later (a fresh setup
# running every data migration), the copies ran just before it and no old code wrote in
# between, so there is nothing to sync: it records the run, and the drop's guard still checks
# every column value and weapon_sources row against `sources` before dropping anything. A
# no-op once the columns are dropped.
class SyncItemSources < ActiveRecord::Migration[8.1]
  SYNCED_AT_KEY = 'item_sources_synced_at'

  def up
    return say('weapons/summons source columns are gone; nothing to sync') unless connection.column_exists?(:weapons, :wiki_raw)

    # The database's clock, which the copies used for their recorded times.
    now = connection.select_all('SELECT clock_timestamp() AS t').cast_values.first
    value = "#{now.utc.iso8601(6)} stored=0"
    connection.execute(<<~SQL.squish)
      INSERT INTO ar_internal_metadata (key, value, created_at, updated_at)
      VALUES (#{connection.quote(SYNCED_AT_KEY)}, #{connection.quote(value)}, now(), now())
      ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()
    SQL
    say 'recorded the sync; the column drop checks every value'
  end

  def down
    # Nothing to undo.
  end
end
