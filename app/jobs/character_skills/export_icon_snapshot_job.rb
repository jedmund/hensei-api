# frozen_string_literal: true

module CharacterSkills
  # Re-exports the character skill icon snapshot (IconSnapshot.export, what
  # granblue:export_character_skill_icons runs) from this database's stored versions, so icons
  # that came from game imports survive a later reparse from wikitext. Reads the database only.
  #
  # Queued by a character skill build that set or changed a version's game_icon (Build::Runner),
  # through schedule: a burst of imports queues one export, DEBOUNCE after the first. A changed
  # snapshot queues the stale build from IconSnapshot.store (in CHARACTER_SKILL_BUILD's mode); an
  # unchanged one stores and queues nothing.
  #
  # Failures keep the stored snapshot: conflicting versions and an export that would drop too many
  # entries are dropped at once (data problems retrying won't fix), and anything else is retried
  # twice an hour apart.
  class ExportIconSnapshotJob < ApplicationJob
    queue_as :maintenance

    DEBOUNCE = 10.minutes
    # A pending export older than this is taken as lost (say, Redis was flushed), and the next
    # icon change queues a new one.
    STALE_AFTER = 1.hour
    PENDING_KEY = 'character_skill_icon_export_pending_at'

    retry_on StandardError, wait: 1.hour, attempts: 3 do |_job, error|
      Rails.logger.warn "[ICON_SNAPSHOT] export failed, keeping the stored snapshot: #{error.class}: #{error.message}"
    end
    discard_on IconSnapshot::ConflictError, IconSnapshot::ShrinkError do |_job, error|
      Rails.logger.warn "[ICON_SNAPSHOT] keeping the stored snapshot: #{error.message}"
    end

    class << self
      # Queues an export DEBOUNCE from now, unless one is already pending. → the job, or nil.
      # The pending marker is a row in ar_internal_metadata, claimed atomically, so concurrent
      # builds queue one export between them.
      def schedule
        set(wait: DEBOUNCE).perform_later if claim_pending?
      end

      def clear_pending
        ActiveRecord::Base.connection.exec_delete(
          ActiveRecord::Base.sanitize_sql_array(['DELETE FROM ar_internal_metadata WHERE key = ?', PENDING_KEY])
        )
      end

      private

      def claim_pending?
        now = Time.current.utc
        sql = <<~SQL.squish
          INSERT INTO ar_internal_metadata (key, value, created_at, updated_at) VALUES (?, ?, ?, ?)
          ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = EXCLUDED.updated_at
          WHERE ar_internal_metadata.updated_at < ?
          RETURNING key
        SQL
        ActiveRecord::Base.connection.select_value(
          ActiveRecord::Base.sanitize_sql_array([sql, PENDING_KEY, now.iso8601, now, now, now - STALE_AFTER])
        ).present?
      end
    end

    def perform
      # Cleared first: a build that changes icons while this export runs queues the next one.
      self.class.clear_pending
      before = IconSnapshot.sha256
      count = IconSnapshot.export
      after = IconSnapshot.sha256
      Rails.logger.info "[ICON_SNAPSHOT] #{after == before ? 'unchanged' : 'updated'}, #{count} icons (sha256 #{after.to_s[0, 12]})"
      count
    end
  end
end
