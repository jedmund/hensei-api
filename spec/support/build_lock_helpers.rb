# frozen_string_literal: true

# CharacterSkills::BuildLock as another process holds it: a separate Postgres session (the test
# transaction pins every thread to one connection, where advisory locks are reentrant).
module BuildLockHelpers
  def with_other_session
    url = ActiveRecord::Base.connection_db_config.url || "postgres:///#{ActiveRecord::Base.connection_db_config.database}"
    connection = PG.connect(url)
    yield connection
  ensure
    connection&.close
  end

  # Holds the stale build's lock (kind :all) or a character build's (kind :character) while the
  # block runs. release_after: seconds lets it go that long after the block started, as a build
  # that finishes while the block waits for it.
  def held_elsewhere(kind, character_id = nil, release_after: nil, &)
    return held_by_session(kind, character_id, &) unless release_after

    locked = Queue.new
    thread = Thread.new do
      held_by_session(kind, character_id) do
        locked << true
        sleep release_after
      end
    end
    locked.pop
    yield
  ensure
    thread&.join
  end

  # Whether another session could take the stale build's lock now (nothing holds any build lock).
  def build_locks_free?
    with_other_session do |session|
      session.exec_params('SELECT pg_try_advisory_lock($1, 0)', [CharacterSkills::BuildLock::BUILDS]).getvalue(0, 0) == 't'
    end
  end

  private

  def held_by_session(kind, character_id)
    builds = CharacterSkills::BuildLock::BUILDS
    with_other_session do |session|
      if kind == :all
        session.exec_params('SELECT pg_advisory_lock($1, 0)', [builds])
      else
        session.exec_params('SELECT pg_advisory_lock_shared($1, 0)', [builds])
        session.exec_params('SELECT pg_advisory_lock($1, hashtext($2))', [CharacterSkills::BuildLock::CHARACTERS, character_id])
      end
      yield
    end
  end
end
