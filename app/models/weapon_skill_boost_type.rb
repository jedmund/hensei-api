# frozen_string_literal: true

class WeaponSkillBoostType < ApplicationRecord
  CATEGORIES = %w[offensive defensive multiattack cap supplemental utility].freeze
  STACKING_RULES = %w[additive multiplicative_by_series highest_only].freeze

  validates :key, presence: true, uniqueness: true
  validates :name_en, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :stacking_rule, presence: true, inclusion: { in: STACKING_RULES }

  scope :capped, -> { where.not(grid_cap: nil) }
  scope :by_category, ->(cat) { where(category: cat) }
end
