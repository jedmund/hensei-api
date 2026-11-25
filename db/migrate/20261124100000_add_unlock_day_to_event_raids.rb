# frozen_string_literal: true

# Which day of an event each of its raids opens on, as whole days after the
# event starts (a Guild War's NM200 opens 3 days in). Null means it's open
# from the start. The home page's event card focuses the raid that opened
# most recently.
class AddUnlockDayToEventRaids < ActiveRecord::Migration[8.1]
  def change
    add_column :event_raids, :unlock_day, :integer
  end
end
