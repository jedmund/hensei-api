# frozen_string_literal: true

# collection_artifacts.raw_data stored each imported artifact's full game payload
# (most of the table's size) and nothing read it. Clear it in batches; the
# column is dropped in a later release. The old code can still write payloads
# until this release is live, so run `rake collection_artifacts:clear_raw_data`
# once after deploy to catch those.
class ClearCollectionArtifactRawData < ActiveRecord::Migration[8.0]
  # Each batch commits on its own instead of one long transaction over the table.
  disable_ddl_transaction!

  def up
    cleared = CollectionArtifacts::RawDataClearer.new.call do |batch, total|
      say "batch #{batch}: #{total} cleared so far" if (batch % 20).zero?
    end
    say "collection_artifacts.raw_data: #{cleared} rows cleared"
  end

  def down
    # No-op: the payloads were not kept.
  end
end
