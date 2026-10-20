# frozen_string_literal: true

module CollectionArtifacts
  # Sets collection_artifacts.raw_data to NULL in primary-key batches. Each batch
  # is its own statement, so outside a transaction it commits on its own and
  # holds row locks only briefly. Rows already NULL are skipped, so running it
  # again only touches payloads written since the last run.
  class RawDataClearer
    BATCH_SIZE = 5_000

    def initialize(batch_size: BATCH_SIZE)
      @batch_size = Integer(batch_size)
    end

    # Returns the number of rows cleared. Yields (batch_number, cleared_so_far)
    # after each batch for progress logging.
    def call
      cleared = 0
      batches = 0
      last_id = nil

      while (upper = next_upper_bound(last_id))
        cleared += clear_range(last_id, upper)
        batches += 1
        last_id = upper
        yield(batches, cleared) if block_given?
      end

      cleared
    end

    private

    attr_reader :batch_size

    def after(last_id)
      scope = CollectionArtifact.unscoped
      last_id ? scope.where('id > ?', last_id) : scope
    end

    # The id that closes the next batch of batch_size rows after last_id.
    def next_upper_bound(last_id)
      after(last_id).order(:id).limit(batch_size).pluck(:id).last
    end

    def clear_range(last_id, upper)
      after(last_id).where('id <= ?', upper).where('raw_data IS NOT NULL').update_all('raw_data = NULL')
    end
  end
end
