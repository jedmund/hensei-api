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
  # block runs.
  def held_elsewhere(kind, character_id = nil)
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

  # Whether another session could take the stale build's lock now (nothing holds any build lock).
  def build_locks_free?
    with_other_session do |session|
      session.exec_params('SELECT pg_try_advisory_lock($1, 0)', [CharacterSkills::BuildLock::BUILDS]).getvalue(0, 0) == 't'
    end
  end
end
