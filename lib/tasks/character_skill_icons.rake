# frozen_string_literal: true

namespace :granblue do
  desc <<~DESC
    Store every character skill version's game_icon as the icon snapshot (one shared
    `sources` row, kind icon_snapshot). The builder falls back to it when a character has no
    game data, and the character build fingerprint includes it, so a changed snapshot
    rebuilds every character. Run it against the database whose icons you trust:

      bin/rails granblue:export_character_skill_icons
  DESC
  task export_character_skill_icons: :environment do
    count = CharacterSkills::IconSnapshot.export
    puts "Stored #{count} character skill icons as the icon snapshot"
  end
end
