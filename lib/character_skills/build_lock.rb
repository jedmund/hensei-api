# frozen_string_literal: true

module CharacterSkills
  # Postgres advisory locks that keep character skill builds from overlapping. The writer reads a
  # character's rows and creates the missing ones, so two builds of one character at once could
  # create duplicate slots or versions.
  #
  #   all:       the stale build (every character). Exclusive on the build key.
  #   character: one character's build. Shared on the build key, so per-character builds run side
  #              by side but never during a stale build, plus exclusive on that character.
  #
  # Session locks. Without wait: they're tried once, so a job that can't have them re-queues itself.
  # With wait: (seconds) they're waited for that long at most (Postgres queues the request, so a
  # waiting stale build isn't starved by a stream of character builds), for callers that can't
  # re-queue: an editor's request, the deploy build. Either way the block runs and the locks are
  # released, or nothing runs and the call returns false.
  module BuildLock
    # A caller that can't go on without the lock gave up waiting for it.
    class Busy < StandardError; end

    # Arbitrary fixed int4 keys, in the two-key form so they can't collide with single bigint locks.
    # The build key is (BUILDS, 0); a character's is (CHARACTERS, hashtext(id)): a hash collision
    # only makes two characters' builds wait for each other.
    BUILDS = 0x4353_4b42 # "CSKB"
    CHARACTERS = 0x4353_4b43 # "CSKC"

    TRY = { exclusive: 'pg_try_advisory_lock', shared: 'pg_try_advisory_lock_shared' }.freeze
    WAIT = { exclusive: 'pg_advisory_lock', shared: 'pg_advisory_lock_shared' }.freeze
    UNLOCK = { exclusive: 'pg_advisory_unlock', shared: 'pg_advisory_unlock_shared' }.freeze
    private_constant :TRY, :WAIT, :UNLOCK

    class << self
      def all(wait: nil, &)
        with_locks([[:exclusive, BUILDS, 0]], wait, &)
      end

      def character(character_id, wait: nil, &)
        with_locks([[:shared, BUILDS, 0], [:exclusive, CHARACTERS, character_id.to_s]], wait, &)
      end

      private

      def with_locks(locks, wait)
        held = []
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + wait.to_f
        locks.each do |mode, key, id|
          return false unless acquire(mode, key, id, deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC))

          held << [mode, key, id]
        end
        yield
        true
      ensure
        held&.reverse_each { |mode, key, id| call(UNLOCK.fetch(mode), key, id) }
      end

      # → whether the lock was taken: tried once when there's no time left, else waited for under
      # lock_timeout (set for the wait only, then put back).
      def acquire(mode, key, id, seconds)
        return call(TRY.fetch(mode), key, id) unless seconds.positive?

        connection = ActiveRecord::Base.connection
        # In a transaction (a savepoint inside one), so lock_timeout can be set for this wait only
        # and a timed-out wait doesn't abort a caller's transaction. Materialized at once: Rails
        # opens transactions lazily, and set_config(..., true) outside one would last one statement.
        connection.transaction(requires_new: true) do
          connection.materialize_transactions
          previous = connection.uncached { connection.select_value("SELECT current_setting('lock_timeout')") }
          apply_lock_timeout("#{(seconds * 1000).ceil}ms")
          call(WAIT.fetch(mode), key, id)
          apply_lock_timeout(previous)
        end
        true
      rescue ActiveRecord::LockWaitTimeout
        false
      end

      def apply_lock_timeout(value)
        sql = ActiveRecord::Base.sanitize_sql_array(["SELECT set_config('lock_timeout', ?, true)", value])
        ActiveRecord::Base.connection.uncached { ActiveRecord::Base.connection.select_value(sql) }
      end

      # function is one of the fixed names above; the keys go in as binds. Never from the query
      # cache: a request caches SELECTs, and a cached lock result would skip taking the lock.
      def call(function, key, id)
        sql = id.is_a?(String) ? "SELECT #{function}(?, hashtext(?))" : "SELECT #{function}(?, ?)"
        sql = ActiveRecord::Base.sanitize_sql_array([sql, key, id])
        ActiveRecord::Base.connection.uncached { ActiveRecord::Base.connection.select_value(sql) }
      end
    end
  end
end
