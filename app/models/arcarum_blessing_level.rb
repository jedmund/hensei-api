# frozen_string_literal: true

##
# One level of an Arcarum Blessing: its effect text, loadout cost and the
# scintillas needed to reach it.
class ArcarumBlessingLevel < ApplicationRecord
  belongs_to :arcarum_blessing, inverse_of: :levels
  has_many :party_blessings, dependent: :restrict_with_error

  validates :level, presence: true, numericality: { only_integer: true, greater_than: 0 },
                    uniqueness: { scope: :arcarum_blessing_id }
  validates :cost, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :scintillas, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
end
