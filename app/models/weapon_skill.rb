# frozen_string_literal: true

class WeaponSkill < ApplicationRecord
  belongs_to :skill
  belongs_to :weapon, primary_key: 'granblue_id', foreign_key: 'weapon_granblue_id', optional: true

  validates :weapon_granblue_id, presence: true
  validates :position, presence: true
  validates :position, uniqueness: { scope: %i[weapon_granblue_id unlock_level] }

  scope :by_position, ->(position) { where(position: position) }
  scope :unlocked_at, ->(level) { where('unlock_level <= ?', level) }
  scope :by_series, ->(series) { where(skill_series: series) }
  scope :by_modifier, ->(modifier) { where(skill_modifier: modifier) }
end
