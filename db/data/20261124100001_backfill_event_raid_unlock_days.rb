# frozen_string_literal: true

# Fills in the days the raids of running and upcoming Guild Wars and Dread
# Barrages open (Event::RAID_UNLOCK_DAYS), so the home page's event card
# follows the schedule. Past events are left alone. Idempotent: only rows
# without a day, and only days inside the event.
class BackfillEventRaidUnlockDays < ActiveRecord::Migration[8.1]
  def up
    events = Event.where(kind: Event::RAID_UNLOCK_DAYS.keys).where(ends_at: Time.current..)
    EventRaid.where(event: events, unlock_day: nil).includes(:event, :raid).find_each do |row|
      day = row.event.scheduled_unlock_day(row.raid)
      next unless day && row.event.starts_at + day.days < row.event.ends_at

      row.update_columns(unlock_day: day, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def down
    # Days set here can't be told apart from ones set by hand
  end
end
