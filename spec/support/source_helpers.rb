# frozen_string_literal: true

# Writes a record's source directly, the way update_columns wrote the old columns: no
# owner hook (no skill build queued), no fetch time unless given. Reloads the record so
# its readers see the new value.
module SourceHelpers
  def put_source(record, kind, value, fetched_at: nil)
    Source.put(record, kind, value, fetched_at: fetched_at, skip_owner_hook: true)
    record.reload
  end

  # Stores the character skill icon snapshot (entries, or the JSON text as exported).
  def put_icon_snapshot(entries)
    CharacterSkills::IconSnapshot.store(entries.is_a?(String) ? entries : JSON.generate(entries))
  end
end

RSpec.configure do |config|
  config.include SourceHelpers
  # The snapshot is loaded once per process; each example starts from its own rows.
  config.before { CharacterSkills::IconSnapshot.reset! }
end
