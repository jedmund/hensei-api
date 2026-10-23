# frozen_string_literal: true

module CharacterSkills
  # Re-exports the character skill icon snapshot (IconSnapshot.export, what
  # granblue:export_character_skill_icons runs) from this database's stored versions. Run by
  # sidekiq-scheduler on the 2nd and the 20th, after the status list refresh (config/sidekiq.yml),
  # so icons that came from game imports since the last export survive a reparse from wikitext.
  # Reads the database only; no network.
  #
  # A changed snapshot queues the stale build from IconSnapshot.store (in CHARACTER_SKILL_BUILD's
  # mode); an unchanged one stores and queues nothing.
  #
  # Failures keep the stored snapshot: conflicting versions are dropped at once (a data problem
  # that retrying won't fix), and anything else is retried twice an hour apart, then dropped until
  # the next scheduled run.
  class ExportIconSnapshotJob < ApplicationJob
    queue_as :maintenance

    retry_on StandardError, wait: 1.hour, attempts: 3 do |_job, error|
      Rails.logger.warn "[ICON_SNAPSHOT] export failed, keeping the stored snapshot: #{error.class}: #{error.message}"
    end
    discard_on IconSnapshot::ConflictError do |_job, error|
      Rails.logger.warn "[ICON_SNAPSHOT] conflicting versions, keeping the stored snapshot: #{error.message}"
    end

    def perform
      before = IconSnapshot.sha256
      count = IconSnapshot.export
      after = IconSnapshot.sha256
      Rails.logger.info "[ICON_SNAPSHOT] #{after == before ? 'unchanged' : 'updated'}, #{count} icons (sha256 #{after.to_s[0, 12]})"
      count
    end
  end
end
