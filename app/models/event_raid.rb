# frozen_string_literal: true

class EventRaid < ApplicationRecord
  include ExpiresHomeFeed

  belongs_to :event, inverse_of: :event_raids
  belongs_to :raid

  validates :raid_id, uniqueness: { scope: :event_id }
  # Whole days after the event starts; null opens the raid with the event
  validates :unlock_day, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :unlocks_during_event
  # A raid linked to a Guild War or Dread Barrage opens on its scheduled day,
  # when the event runs that long
  before_validation :schedule_unlock_day, on: :create

  # When the raid opens, or nil when it opens with the event
  def unlocks_at
    unlock_day && event&.starts_at && (event.starts_at + unlock_day.days)
  end

  private

  def schedule_unlock_day
    return if unlock_day || !event

    day = event.scheduled_unlock_day(raid)
    self.unlock_day = day if day && event.starts_at && event.ends_at && event.starts_at + day.days < event.ends_at
  end

  def unlocks_during_event
    return unless unlocks_at && event.ends_at
    return if unlocks_at < event.ends_at

    errors.add(:unlock_day, 'must be before the event ends')
  end
end
