# frozen_string_literal: true

# The JST hour an event's scheduled raids open at on their unlock day (null:
# unlock_day whole days after the start). Guild Wars switch over at 0:00 JST
# and Dread Barrages at 19:00 JST.
class AddRaidUnlockHourToEvents < ActiveRecord::Migration[8.1]
  HOURS = { 3 => 0, 4 => 19 }.freeze # unite_and_fight, dread_barrage

  def up
    add_column :events, :raid_unlock_hour, :integer
    HOURS.each { |kind, hour| execute "UPDATE events SET raid_unlock_hour = #{hour} WHERE kind = #{kind}" }
  end

  def down
    remove_column :events, :raid_unlock_hour
  end
end
