# frozen_string_literal: true

class Difficulty < ApplicationRecord
  has_many :parties, dependent: :nullify

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9_-]+\z/, message: 'lowercase letters, numbers, hyphens and underscores only' }
  validates :min_score, :max_score, presence: true,
                                    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validate :max_score_greater_than_min_score
  validate :tier_coverage_complete

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

  # The set of all tiers must tile [0, 100] with no overlaps and no gaps wider
  # than one score quantum (Calculator#composite_score rounds to 2 decimals, so
  # adjacent tiers may sit at .99 / .00 with a 0.01 difference). For multi-tier
  # edits (e.g. splitting one tier in two), batch the changes through
  # PartyDifficulty::DraftWorkspace so the intermediate state isn't persisted.
  TIER_QUANTUM = 0.01

  def tier_coverage_complete
    return if min_score.blank? || max_score.blank? || max_score <= min_score

    proposed = (Difficulty.where.not(id: id).to_a + [self]).sort_by { |t| t.min_score.to_f }

    if proposed.first.min_score.to_f.abs > TIER_QUANTUM
      errors.add(:base, 'tier coverage must start at 0.00')
      return
    end
    if (100.0 - proposed.last.max_score.to_f).abs > TIER_QUANTUM
      errors.add(:base, 'tier coverage must end at 100.00')
      return
    end

    proposed.each_cons(2).find do |prev_tier, next_tier|
      gap = next_tier.min_score.to_f - prev_tier.max_score.to_f
      if gap.negative?
        errors.add(:base, "tier overlaps an existing tier near #{prev_tier.max_score}")
      elsif gap > TIER_QUANTUM + 1e-6
        errors.add(:base, "tier leaves a coverage gap between #{prev_tier.max_score} and #{next_tier.min_score}")
      end
      errors[:base].any?
    end
  end

  def bump_ruleset_version
    DifficultyConfig.bump_version!
  end
end
