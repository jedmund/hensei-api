# frozen_string_literal: true

# Marks the Unite and Fight raid group with content_mode 'unite_and_fight', so
# the web app can hide Crucible Seals on its teams with a flag check. Matched
# by name, not id; a no-op when the group doesn't exist or already has a mode.
class MarkUniteAndFightRaidGroup < ActiveRecord::Migration[8.1]
  NAME = 'Unite and Fight'

  def up
    RaidGroup.reset_column_information
    count = RaidGroup.where(name_en: NAME, content_mode: nil)
                     .update_all(content_mode: RaidGroup::UNITE_AND_FIGHT, updated_at: Time.current)
    say "Marked #{count} raid group(s) as Unite and Fight"
  end

  def down
    RaidGroup.where(name_en: NAME, content_mode: RaidGroup::UNITE_AND_FIGHT).update_all(content_mode: nil)
  end
end
