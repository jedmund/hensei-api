# frozen_string_literal: true

# Runs Granblue::ItemSourceSync once (as `bin/rails granblue:sync_item_sources`), on the deploy
# after PR 7b: copies into `sources` what the previous code wrote to the old weapon and summon
# columns and to weapon_sources after the 7b copy migrations ran. The current code no longer
# writes those, so this is the last time anything can differ. The sync records its run
# (ar_internal_metadata item_sources_synced_at), which the column-drop migration checks.
#
# No build jobs from a pre-deploy migration: a weapon whose stored source this changes gets a
# new fingerprint, and the deploy build rebuilds it. Logs counts only.
class SyncItemSources < ActiveRecord::Migration[8.1]
  def up
    log = StringIO.new
    Granblue::ItemSourceSync.new(io: log).call
    log.string.each_line { |line| say line.chomp }
  end

  def down
    # Nothing to undo: it only copied current old-column values into the store.
  end
end
