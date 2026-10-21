# frozen_string_literal: true

# Runs CharacterSkills::SourceSync once (as `bin/rails granblue:sync_character_sources`):
# copies into `sources` anything the previous code wrote to the old character columns after
# the copy migration ran. The current code no longer writes those columns, so this is the
# last time anything can differ. Records the run (ar_internal_metadata
# character_sources_synced_at), which the column-drop migration checks.
#
# No build jobs from a pre-deploy migration: a character whose source this stores gets a new
# fingerprint, and the deploy build rebuilds it. Logs counts only.
class SyncCharacterSources < ActiveRecord::Migration[8.1]
  def up
    log = StringIO.new
    CharacterSkills::SourceSync.new(io: log, enqueue_builds: false).call
    log.string.each_line { |line| say line.chomp }
  end

  def down
    # Nothing to undo: it only copied current column values into the store.
  end
end
