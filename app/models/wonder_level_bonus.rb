# frozen_string_literal: true

# What one level of a leveled Wonder adds. stat is one of our stat keys
# (see WonderBonusCalculator); value is a percentage.
class WonderLevelBonus < ApplicationRecord
  self.table_name = 'wonder_level_bonuses'

  belongs_to :wonder, inverse_of: :level_bonuses

  validates :level, presence: true, numericality: { only_integer: true, greater_than: 0 },
                    uniqueness: { scope: :wonder_id }
  validates :stat, presence: true
  validates :value, presence: true, numericality: { only_integer: true }
end
