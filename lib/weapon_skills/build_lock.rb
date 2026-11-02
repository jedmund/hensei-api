# frozen_string_literal: true

module WeaponSkills
  # The advisory lock (AdvisoryLock) that keeps weapon-skill builds from overlapping: the deploy
  # build, a single weapon's build after a save (BuildJob), an editor's Reparse, the rake task.
  # One exclusive key for all of them: every run ends with the catalogue-wide curation sync and
  # key extraction (Build::Runner#finish), so even builds of different weapons can't overlap.
  # Build::Runner#call takes it.
  module BuildLock
    # A caller gave up waiting for a running build.
    class Busy < StandardError; end

    BUILDS = 0x5753_4b42 # "WSKB"

    # → true when the block ran, false when the lock wasn't free (within wait: seconds).
    def self.build(wait: nil, &)
      AdvisoryLock.with([[:exclusive, BUILDS, 0]], wait: wait, &)
    end
  end
end
