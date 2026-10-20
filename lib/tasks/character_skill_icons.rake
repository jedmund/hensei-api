# frozen_string_literal: true

namespace :granblue do
  desc <<~DESC
    Export every character skill version's game_icon to data/character_skills/icons.json.
    The builder falls back to this snapshot when a character has no game data. Run it
    against a database you trust, read-only, and commit the file:

      PGOPTIONS='-c default_transaction_read_only=on' DATABASE_URL=postgres://localhost/hensei_dev \\
        bin/rails granblue:export_character_skill_icons
  DESC
  task export_character_skill_icons: :environment do
    count = CharacterSkills::IconSnapshot.export
    puts "Exported #{count} character skill icons to #{CharacterSkills::IconSnapshot::DEFAULT_PATH}"
  end
end
