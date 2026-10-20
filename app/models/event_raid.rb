# frozen_string_literal: true

class EventRaid < ApplicationRecord
  belongs_to :event, inverse_of: :event_raids
  belongs_to :raid

  validates :raid_id, uniqueness: { scope: :event_id }
end
