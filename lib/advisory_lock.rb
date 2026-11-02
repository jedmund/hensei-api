# frozen_string_literal: true

# Postgres session advisory locks, for builds that must not overlap (CharacterSkills::BuildLock,
# WeaponSkills::BuildLock name the keys).
#
#   AdvisoryLock.with([[:exclusive, KEY, 0], [:shared, OTHER, "id"]], wait: nil) { ... } # → true/false
#
# Each lock is [mode, int4 key, id]: two-key form, so they can't collide with single bigint locks;
# a String id is hashed (hashtext), so a collision only makes two ids wait for each other.
#
# Without wait: tried once, so a job that can't have them re-queues itself. With wait: (seconds)
# waited for that long at most (Postgres queues the request, so a waiting exclusive build isn't
# starved by a stream of shared ones). Either way the block runs and the locks are released, or
# nothing runs and the call returns false.
module AdvisoryLock
  TRY = { exclusive: 'pg_try_advisory_lock', shared: 'pg_try_advisory_lock_shared' }.freeze
  WAIT = { exclusive: 'pg_advisory_lock', shared: 'pg_advisory_lock_shared' }.freeze
  UNLOCK = { exclusive: 'pg_advisory_unlock', shared: 'pg_advisory_unlock_shared' }.freeze
  private_constant :TRY, :WAIT, :UNLOCK

  class << self
    def with(locks, wait: nil)
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

    private

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
