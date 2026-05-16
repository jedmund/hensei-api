# frozen_string_literal: true

# Adds a notes_synced flag to grid_weapons and grid_summons. When true, the
# item participates in a "notes sync group" that mirrors its description and
# substitutions across every grid item in the same party with the same
# weapon_id / summon_id (i.e. duplicates of the same canonical item). The
# fan-out logic lives in app/services/notes_sync.rb; this migration just
# carries the flag. Existing rows start unsynced.
class AddNotesSyncedToGridItems < ActiveRecord::Migration[8.0]
  def change
    add_column :grid_weapons, :notes_synced, :boolean, null: false, default: false
    add_column :grid_summons, :notes_synced, :boolean, null: false, default: false
  end
end
