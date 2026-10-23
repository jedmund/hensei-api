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
  # Session locks, taken without waiting: the block runs and the locks are released, or nothing
  # runs and the call returns false so the job can re-queue itself.
  module BuildLock
    # Arbitrary fixed int4 keys, in the two-key form so they can't collide with single bigint locks.
    # The build key is (BUILDS, 0); a character's is (CHARACTERS, hashtext(id)): a hash collision
    # only makes two characters' builds wait for each other.
    BUILDS = 0x4353_4b42 # "CSKB"
    CHARACTERS = 0x4353_4b43 # "CSKC"

    TRY = { exclusive: 'pg_try_advisory_lock', shared: 'pg_try_advisory_lock_shared' }.freeze
    UNLOCK = { exclusive: 'pg_advisory_unlock', shared: 'pg_advisory_unlock_shared' }.freeze
    private_constant :TRY, :UNLOCK

    class << self
      def all(&)
        with_locks([[:exclusive, BUILDS, 0]], &)
      end

      def character(character_id, &)
        with_locks([[:shared, BUILDS, 0], [:exclusive, CHARACTERS, character_id.to_s]], &)
      end

      private

      def with_locks(locks)
        held = []
        locks.each do |mode, key, id|
          return false unless call(TRY.fetch(mode), key, id)

          held << [mode, key, id]
        end
        yield
        true
      ensure
        held&.reverse_each { |mode, key, id| call(UNLOCK.fetch(mode), key, id) }
      end

      # function is one of the fixed names above; the keys go in as binds.
      def call(function, key, id)
        sql = id.is_a?(String) ? "SELECT #{function}(?, hashtext(?))" : "SELECT #{function}(?, ?)"
        ActiveRecord::Base.connection.select_value(ActiveRecord::Base.sanitize_sql_array([sql, key, id]))
      end
    end
  end
end
