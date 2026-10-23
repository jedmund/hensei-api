# frozen_string_literal: true

module Granblue
  # Development only: keeps the curation overlay (data/weapon_skill_curation/) in step
  # with the local database, so curation shows up in `git status` without anyone
  # remembering to export it (docs/weapon-skill-curation.md).
  #
  # Saving or deleting a curated row marks the snapshot dirty; the dirty flag is
  # flushed after each request and when the process exits. Rake tasks that may write
  # with update_all (data migrations, reparses) skip callbacks, so their exit runs a
  # drift check instead. Set CURATION_AUTO_EXPORT=0 to turn it off.
  module CurationAutoExport
    DIRTY = Concurrent::AtomicBoolean.new(false)
    LOCK = Mutex.new
    # Their writes can bypass model callbacks.
    BULK_TASK_PREFIXES = %w[granblue: data: db:migrate].freeze
    # Never auto-export around the curation tasks themselves: the drift check must
    # report what's really unexported, and sync/export manage the file already.
    CURATION_TASKS = %w[granblue:weapon_skill_curation_drift granblue:export_weapon_skill_curation
                        granblue:sync_weapon_skill_curation granblue:split_weapon_skill_curation].freeze

    module_function

    def enabled?
      Rails.env.development? && ENV["CURATION_AUTO_EXPORT"] != "0"
    end

    def mark_dirty!
      DIRTY.make_true if enabled?
    end

    def flush!
      return unless enabled? && DIRTY.make_false

      export!
    end

    # For processes that may have written without callbacks.
    def export_if_drifted!
      return unless enabled?

      drift = CurationSnapshot.drift
      export!(drift) if drift.values_at("missing", "changed").any?(&:present?)
    end

    def rake_bulk_task?(task_names)
      return false if task_names.any? { |name| CURATION_TASKS.include?(name) }

      task_names.any? { |name| name.start_with?(*BULK_TASK_PREFIXES) }
    end

    # The export rewrites the whole file, so it waits while the snapshot holds rows
    # this database doesn't (a teammate's curation, or a curated row deleted here) —
    # exporting then would drop them from git.
    def export!(drift = CurationSnapshot.drift)
      LOCK.synchronize do
        if drift["unapplied"].any?
          Rails.logger.warn "[curation] not exporting: #{drift['unapplied'].size} snapshot rows are missing " \
                            "from this database. Run bin/rails granblue:sync_weapon_skill_curation " \
                            "(or remove them from data/weapon_skill_curation/ if you deleted them on purpose)."
          return false
        end

        CurationSnapshot.export
        Rails.logger.info "[curation] exported #{CurationSnapshot::DIR.relative_path_from(Rails.root)}"
        true
      end
    rescue StandardError => e
      Rails.logger.warn "[curation] auto-export failed: #{e.class}: #{e.message}"
      false
    end
  end
end
