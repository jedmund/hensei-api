# frozen_string_literal: true

class JobSkill < ApplicationRecord
  alias eql? ==

  include PgSearch::Model

  belongs_to :job

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
end
