# frozen_string_literal: true

##
# The skills a job can equip, for the skill picker: its own non-main skills,
# every job's subskills, and the EMP and base skills of its class line. Takes
# an optional text query and a +group+ filter (a color, EMP or base).
#
# Text search and listing differ in the base skills they offer: a search
# finds base skills of the jobs sharing this job's base job, while the list
# offers the base job's own.
class JobSkillSearchQuery < CatalogSearchQuery
  EMP_GROUP = 4
  BASE_GROUP = 5

  # @param job [Job] the job equipping the skills
  def initialize(params, locale:, job:)
    super(params, locale: locale)
    @job = job
  end

  def call
    (text_query? ? searched_relations : listed_relations).compact.reduce(:or)
  end

  private

  def searched_relations
    skills = searched(JobSkill.joins(:job)).where(group_conditions)
    [
      skills.where(job: @job.id, main: false),
      skills.where(sub: true).where.not(job: @job.id),
      base_job && skills.where(job: { base_job: base_job.id }, emp: true).where.not(job: @job.id),
      base_job && skills.where(job: { base_job: base_job.id }, base: true).where.not(job: @job.id)
    ]
  end

  def listed_relations
    skills = JobSkill.where(group_conditions)
    [
      skills.joins(:job).where(job: @job.id, main: false),
      skills.where(sub: true).where.not(job: @job.id),
      base_job && skills.where(job: base_job.id, base: true).where.not(job: @job.id),
      base_job && skills.joins(:job).where(job: { base_job: base_job.id }, emp: true).where.not(job: @job.id)
    ]
  end

  # Groups 0-3 are the colors of plain skills
  def group_conditions
    group = filter_value('group')
    return {} if group.blank?

    case group.to_i
    when 0...EMP_GROUP then { color: group.to_i, emp: false, base: false }
    when EMP_GROUP then { emp: true }
    when BASE_GROUP then { base: true }
    else {}
    end
  end

  # Base jobs have none
  def base_job
    @job.base_job
  end
end
