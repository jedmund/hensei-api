# frozen_string_literal: true

# Clears collection_artifacts.raw_data written after the first clear
# (20261020150000) and before the release that stopped writing it, as
# `bin/rails collection_artifacts:clear_raw_data` does. Batched SQL updates by id
# (no callbacks or jobs), each batch its own statement; rows already NULL are
# skipped, so it's a no-op when the task already ran. Logs counts only.
class ClearCollectionArtifactRawDataAgain < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  BATCH = 5_000

  def up
    cleared = 0
    last_id = nil
    loop do
      ids = select_values(<<~SQL.squish)
        SELECT id FROM collection_artifacts #{"WHERE id > #{quote(last_id)}" if last_id} ORDER BY id LIMIT #{BATCH}
      SQL
      break if ids.empty?

      cleared += exec_update(<<~SQL.squish)
        UPDATE collection_artifacts SET raw_data = NULL
        WHERE id #{last_id ? "> #{quote(last_id)}" : 'IS NOT NULL'} AND id <= #{quote(ids.last)} AND raw_data IS NOT NULL
      SQL
      last_id = ids.last
    end
    say "collection_artifacts.raw_data: #{cleared} rows cleared"
  end

  def down
    # No-op: the payloads were not kept.
  end

  private

  def quote(value) = connection.quote(value)
end
