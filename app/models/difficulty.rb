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

  # The set of all tiers must tile [0, 100] with no overlaps and no gaps wider
  # than one score quantum (Calculator#composite_score rounds to 2 decimals, so
  # adjacent tiers may sit at .99 / .00 with a 0.01 difference). For multi-tier
  # edits (e.g. splitting one tier in two), batch the changes through
  # PartyDifficulty::DraftWorkspace so the intermediate state isn't persisted.
  TIER_QUANTUM = 0.01

  # Returns aggregate error messages for a proposed tier set. The set is any
  # collection of objects responding to `name` / `min_score` / `max_score`.
  # Tiers with blank or inverted bounds are surfaced as errors so callers like
  # PartyDifficulty::DraftWorkspace#commit! can reject them up front instead
  # of letting per-row save raise ActiveRecord::RecordInvalid mid-apply.
  def self.coverage_errors_for(tiers)
    errors = []
    valid = []
    tiers.each do |t|
      label = t.try(:name).presence || t.try(:slug).presence || t.try(:id) || 'unnamed'
      if t.min_score.blank? || t.max_score.blank?
        errors << "tier #{label} is missing min_score or max_score"
      elsif t.max_score <= t.min_score
        errors << "tier #{label} has max_score not greater than min_score"
      else
        valid << t
      end
    end

    return errors + ['tier coverage is empty'] if valid.empty?

    proposed = valid.sort_by { |t| t.min_score.to_f }
    errors << 'tier coverage must start at 0.00' if proposed.first.min_score.to_f.abs > TIER_QUANTUM
    errors << 'tier coverage must end at 100.00' if (100.0 - proposed.last.max_score.to_f).abs > TIER_QUANTUM

    proposed.each_cons(2) do |prev_tier, next_tier|
      gap = next_tier.min_score.to_f - prev_tier.max_score.to_f
      if gap.negative?
        errors << "tier overlaps an existing tier near #{prev_tier.max_score}"
      elsif gap > TIER_QUANTUM + 1e-6
        errors << "tier leaves a coverage gap between #{prev_tier.max_score} and #{next_tier.min_score}"
      end
    end

    errors
  end

  # Yields with the per-row tier coverage validation suppressed. Use only when
  # the caller will validate the aggregate post-write state itself — for
  # example PartyDifficulty::DraftWorkspace#commit!, which pre-validates the
  # merged canonical+drafts set and then applies multiple tier updates in
  # sequence whose intermediate states are intentionally inconsistent.
  def self.with_coverage_validation_skipped
    prev = Thread.current[:difficulty_skip_coverage_validation]
    Thread.current[:difficulty_skip_coverage_validation] = true
    yield
  ensure
    Thread.current[:difficulty_skip_coverage_validation] = prev
  end

  private

  def max_score_greater_than_min_score
    return if min_score.blank? || max_score.blank?

    errors.add(:max_score, 'must be greater than min_score') if max_score <= min_score
  end

  def tier_coverage_complete
    return if Thread.current[:difficulty_skip_coverage_validation]
    return if min_score.blank? || max_score.blank? || max_score <= min_score

    proposed = Difficulty.where.not(id: id).to_a + [self]
    self.class.coverage_errors_for(proposed).each { |msg| errors.add(:base, msg) }
  end

  def bump_ruleset_version
    DifficultyConfig.bump_version!
  end
end
