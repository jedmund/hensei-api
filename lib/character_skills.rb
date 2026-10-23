# frozen_string_literal: true

# The character-skill build: a character's stored sources (wiki_raw, wiki_raw_jp,
# game_raw_en, game_raw_jp), the statuses catalogue and the icon snapshot in; its
# character_skills graph out, upserted by natural key. See CharacterSkills::Build::Runner.
module CharacterSkills
  BUILD_MODES = %w[off shadow write].freeze

  # CHARACTER_SKILL_BUILD: what the deploy build does. "off" (nothing), "shadow" (build,
  # diff, roll back; never fails a deploy) or "write" (stale characters are rebuilt).
  # Read here and nowhere else.
  def self.build_mode
    mode = ENV.fetch("CHARACTER_SKILL_BUILD", "off").to_s.strip.downcase
    BUILD_MODES.include?(mode) ? mode : "off"
  end
end
