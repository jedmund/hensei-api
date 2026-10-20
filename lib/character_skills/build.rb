# frozen_string_literal: true

module CharacterSkills
  # Turns one character's stored sources into its skill rows: Granblue::Parsers::CharacterSkillParser#graph
  # (pure) → Build::Writer (upsert by natural key). Build::Runner drives it; Build::Fingerprint
  # decides which characters are stale.
  module Build
    # Bump whenever the builder's output changes on purpose: every character becomes stale
    # and the next deploy rebuilds it.
    VERSION = 1
  end
end
