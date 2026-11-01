# frozen_string_literal: true

# max_awakening_level 0 meant "no awakenings", which NULL already says; every weapon that
# has awakenings is at 4 to 20. The model now accepts nil or 1 and up.
#
# update_all writes the column alone and sets updated_at with it, like the other bulk
# catalogue writes, so the admin list's ETag moves. Rerunnable: cleared rows no longer match.
class NullZeroWeaponAwakeningLevels < ActiveRecord::Migration[8.1]
  def up
    weapons = Class.new(ActiveRecord::Base) { self.table_name = 'weapons' }
    count = weapons.where(max_awakening_level: 0).update_all(max_awakening_level: nil, updated_at: Time.current)
    say "weapons: #{count} zero max_awakening_level values set to NULL"
  end

  def down
    # Nothing to undo: 0 and NULL both meant no awakenings.
  end
end
