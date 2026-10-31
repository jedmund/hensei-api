# frozen_string_literal: true

# One element a user has a team for in a trackable raid.
class UserRaidElement < ApplicationRecord
  ELEMENTS = GranblueEnums::ELEMENT_ENUM.values.freeze

  belongs_to :user
  belongs_to :raid

  validates :element, presence: true, inclusion: { in: ELEMENTS }
  validates :element, uniqueness: { scope: %i[user_id raid_id] }
end
