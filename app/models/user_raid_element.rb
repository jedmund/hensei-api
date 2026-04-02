# frozen_string_literal: true

class UserRaidElement < ApplicationRecord
  belongs_to :user
  belongs_to :raid

  validates :element, presence: true, inclusion: { in: 1..6 }
  validates :element, uniqueness: { scope: [:user_id, :raid_id] }
end
