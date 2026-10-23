# frozen_string_literal: true

namespace :granblue do
  desc <<~DESC
    Store every character skill version's game_icon as the icon snapshot (one shared
    `sources` row, kind icon_snapshot). The builder falls back to it when a character has no
    game data, and the character build fingerprint includes it, so a changed snapshot
    rebuilds every character. Run it against the database whose icons you trust:

      bin/rails granblue:export_character_skill_icons

    It refuses to drop more than IconSnapshot::MAX_REMOVED stored entries; allow_shrink=1 overrides.
  DESC
  task export_character_skill_icons: :environment do
    max_removed = ENV['allow_shrink'] ? nil : CharacterSkills::IconSnapshot::MAX_REMOVED
    count = CharacterSkills::IconSnapshot.export(max_removed: max_removed)
    puts "Stored #{count} character skill icons as the icon snapshot"
  end
end
