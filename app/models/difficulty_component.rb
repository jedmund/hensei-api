# frozen_string_literal: true

class DifficultyComponent < ApplicationRecord
  COMPONENTS = %w[weapon character summon job accessory].freeze

  validates :name, presence: true, inclusion: { in: COMPONENTS }, uniqueness: true
  validates :weight, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :min_count_to_score, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  after_save :bump_ruleset_version
  after_destroy :bump_ruleset_version

  scope :enabled, -> { where(enabled: true) }

  def self.for(name)
    find_by(name: name.to_s)
  end

  def blueprint
    DifficultyComponentBlueprint
  end

  private

  def bump_ruleset_version
    DifficultyConfig.bump_version!
  end
end
