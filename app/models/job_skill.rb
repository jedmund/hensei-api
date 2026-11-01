# frozen_string_literal: true

class JobSkill < ApplicationRecord
  alias eql? ==

  include PgSearch::Model

  belongs_to :job

  # Slugs name the skill's image (<slug>.png), so they're kebab-case. A skill
  # several jobs share (Counter, Phalanx) has a row per job with one slug.
  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
  COLORS = { Yellow: 0, Blue: 1, Red: 2, Green: 3, Purple: 4 }.freeze

  validates :name_en, :name_jp, presence: true
  validates :slug, presence: true, format: { with: SLUG_FORMAT }, uniqueness: { scope: :job_id }
  validates :color, inclusion: { in: COLORS.values }
  validates :order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :action_id, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  # A new skill without an order goes after its job's other skills.
  before_validation :assign_next_order, on: :create

  pg_search_scope :en_search,
                  against: :name_en,
                  using: {
                    tsearch: {
                      prefix: true,
                      dictionary: 'simple'
                    }
                  }

  pg_search_scope :ja_search,
                  against: :name_jp,
                  using: {
                    tsearch: {
                      prefix: true,
                      dictionary: 'simple'
                    }
                  }

  def blueprint
    JobSkillBlueprint
  end

  def display_resource(skill)
    skill.name_en
  end

  ##
  # Whether this skill can't be equipped as a subskill by the given job: another
  # job's main skill, or an EMP or base skill from a different job line.
  #
  # Origin-row jobs (Lancer Origin, Rising Force) have no base_job, so base jobs
  # are compared nil-safely, and the skill-kind flag short-circuits first
  # (equipping a cross-job subskill must not evaluate the EMP comparison).
  #
  # @param job [Job]
  # @return [Boolean]
  def incompatible_with?(job)
    mismatched_main = (self.job.id != job.id) && main && !sub
    mismatched_emp = emp && self.job.id != job.id && self.job.base_job&.id != job.base_job&.id
    mismatched_base = base && self.job.base_job && (job.row != 'ex2' || self.job.base_job.id != job.base_job&.id)

    return false if %w[4 5 ex2].include?(job.row) && base && !mismatched_base

    mismatched_emp || mismatched_main
  end

  def ==(other)
    self.class == other.class && id == other.id
  end

  private

  def assign_next_order
    return unless order.nil? && job_id.present?

    self.order = (JobSkill.where(job_id: job_id).maximum(:order) || 0) + 1
  end
end
