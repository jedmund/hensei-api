# frozen_string_literal: true

# Which characters each character-specific Wonder boosts. Every version of a
# character counts and duo units don't (owner, 2026-11-21), so a series or
# the game's character ids are enough; the API resolves them, picking up new
# versions on its own. Idempotent: sets the fields on whichever exist.
class SetWonderCharacterRequirements < ActiveRecord::Migration[8.1]
  REQUIREMENTS = {
    # Shield of Eternal Splendor
    '9003' => { required_character_series: 'eternal', required_character_game_ids: [] },
    # Divine Stamp Book: the Divine Generals are the zodiac series
    '9016' => { required_character_series: 'zodiac', required_character_game_ids: [] },
    # Letters from Dad: Katalina, Io, Eugen, Rackam, Rosetta, Lyria
    '29' => { required_character_series: nil, required_character_game_ids: [2005, 2006, 2007, 2008, 2010, 2124] }
  }.freeze

  def up
    REQUIREMENTS.each do |granblue_id, fields|
      Wonder.where(granblue_id: granblue_id).update_all(fields)
    end
  end

  def down
    Wonder.where(granblue_id: REQUIREMENTS.keys)
          .update_all(required_character_series: nil, required_character_game_ids: [])
  end
end
