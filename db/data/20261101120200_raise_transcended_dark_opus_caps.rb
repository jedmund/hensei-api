# frozen_string_literal: true

# Transcended Dark Opus weapons cap at level 250 and skill level 25, like every other
# transcended weapon, but were stored at the ULB caps of 200/20 (the twelve Renunciation
# and Repudiation weapons).
#
# update_all writes the columns alone and sets updated_at with them, like the other bulk
# catalogue writes, so the admin list's ETag moves. Only rows still at 200/20 change, so
# a later hand edit is kept and a rerun does nothing.
class RaiseTranscendedDarkOpusCaps < ActiveRecord::Migration[8.1]
  def up
    weapons = Class.new(ActiveRecord::Base) { self.table_name = 'weapons' }
    series_ids = Class.new(ActiveRecord::Base) { self.table_name = 'weapon_series' }
                      .where(slug: 'dark-opus').select(:id)

    count = weapons.where(weapon_series_id: series_ids, transcendence: true, max_level: 200, max_skill_level: 20)
                   .update_all(max_level: 250, max_skill_level: 25, updated_at: Time.current)
    say "weapons: #{count} transcended Dark Opus weapons raised to 250/25"
  end

  def down
    # Not reversed: 200/20 was wrong.
  end
end
