# frozen_string_literal: true

class Difficulty < ApplicationRecord
  has_many :parties, dependent: :nullify

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9_-]+\z/, message: 'lowercase letters, numbers, hyphens and underscores only' }
  validates :min_score, :max_score, presence: true,
                                    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validate :max_score_greater_than_min_score

  after_save :bump_ruleset_version
  after_destroy :bump_ruleset_version

  scope :ordered, -> { order(:sort_order, :min_score) }

  def self.for_score(score)
    return nil if score.nil?

    ordered.detect { |d| score >= d.min_score && score <= d.max_score }
  end

  def blueprint
    DifficultyBlueprint
  end

  private

  def max_score_greater_than_min_score
    return if min_score.blank? || max_score.blank?

    errors.add(:max_score, 'must be greater than min_score') if max_score <= min_score
  end

  def bump_ruleset_version
    DifficultyConfig.bump_version!
  end
end
