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
  # Session locks (AdvisoryLock): without wait: tried once, so a job that can't have them re-queues
  # itself; with wait: (seconds) waited for that long at most, for callers that can't re-queue: an
  # editor's request, the deploy build. Either way the block runs and the locks are released, or
  # nothing runs and the call returns false.
  module BuildLock
    # A caller that can't go on without the lock gave up waiting for it.
    class Busy < StandardError; end

    # Arbitrary fixed int4 keys. The build key is (BUILDS, 0); a character's is
    # (CHARACTERS, hashtext(id)): a hash collision only makes two characters' builds wait for each other.
    BUILDS = 0x4353_4b42 # "CSKB"
    CHARACTERS = 0x4353_4b43 # "CSKC"

    class << self
      def all(wait: nil, &)
        AdvisoryLock.with([[:exclusive, BUILDS, 0]], wait: wait, &)
      end

      def character(character_id, wait: nil, &)
        AdvisoryLock.with([[:shared, BUILDS, 0], [:exclusive, CHARACTERS, character_id.to_s]], wait: wait, &)
      end
    end
  end
end
