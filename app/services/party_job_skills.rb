# frozen_string_literal: true

##
# Changes a party's job and its job skills, following the game's rules:
# a job brings its main skills; skills the new job can't use are dropped;
# moving from a row I-III job to a row IV/V/EX II job drops a third
# subskill; those jobs take at most two skills of each type (sub or EMP).
#
# Only assigns attributes; the caller saves the party.
#
# @example
#   PartyJobSkills.new(party).change_job(job_id)
#   PartyJobSkills.new(party).equip('skill2_id' => skill_id)
class PartyJobSkills
  SKILL_KEYS = %w[skill1_id skill2_id skill3_id].freeze
  # Rows that limit skills by type
  LIMITED_ROWS = %w[4 5 ex2].freeze
  MAX_SKILLS_OF_TYPE = 2

  # @param party [Party]
  def initialize(party)
    @party = party
  end

  # Sets the job and its main skills. -1 clears the job and every skill.
  # @param job_id [String, Integer]
  # @raise [ActiveRecord::RecordNotFound] for an unknown job
  def change_job(job_id)
    return clear_job if job_id == -1

    old_job = @party.job
    job = Job.find(job_id)
    @party.job = job
    JobSkill.where(job: job.id, main: true).each_with_index do |skill, index|
      @party["skill#{index}_id"] = skill.id
    end

    # Check for incompatible Base and EMP skills
    SKILL_KEYS.each do |key|
      @party[key] = nil if @party[key] && JobSkill.find(@party[key]).incompatible_with?(@party.job)
    end

    @party['skill3_id'] = nil if drops_third_subskill?(old_job, job)
  end

  # Puts skills in positions 1-3, swapping one already equipped elsewhere.
  # @param skills [#[], #keys] skill1_id..skill3_id => JobSkill id
  # @raise [Api::V1::NoJobSkillProvidedError] when no skill is given
  # @raise [ActiveRecord::RecordNotFound] for an unknown skill
  # @raise [Api::V1::IncompatibleSkillError, Api::V1::TooManySkillsOfTypeError]
  def equip(skills)
    raise Api::V1::NoJobSkillProvidedError unless SKILL_KEYS.any? { |key| skills[key] }

    # Determine which incoming keys contain new skills
    new_skill_keys = skills.keys.select { |key| SKILL_KEYS.include?(key) }
    return if new_skill_keys.empty?

    new_skills = load_skills(new_skill_keys.map { |key| skills[key] })
    existing_skills = { 1 => @party.skill1, 2 => @party.skill2, 3 => @party.skill3 }
    merged = merge_skills(existing_skills, new_skills, positions(new_skill_keys))

    @party.attributes = merged.each_with_object({}) do |(index, skill), memo|
      memo["skill#{index}_id"] = skill&.id
    end
  end

  private

  def clear_job
    @party.job = nil
    %w[skill0_id skill1_id skill2_id skill3_id].each { |key| @party[key] = nil }
  end

  # Going from a row I-III job to a row IV, V or EX II job with three
  # subskills equipped
  def drops_third_subskill?(old_job, job)
    old_job && %w[1 2 3].include?(old_job.row) && LIMITED_ROWS.include?(job.row) &&
      [@party.skill1, @party.skill2, @party.skill3].all? { |skill| skill&.sub }
  end

  # Loads the skills once, in the given order, checking each exists and
  # suits the party's job.
  def load_skills(ids)
    loaded = JobSkill.where(id: ids).index_by(&:id)
    ids.map do |id|
      skill = loaded[id]
      raise ActiveRecord::RecordNotFound, "Couldn't find JobSkill" unless skill
      raise Api::V1::IncompatibleSkillError.new(job: @party.job, skill: skill) if skill.incompatible_with?(@party.job)

      skill
    end
  end

  # 'skill2_id' => 2
  def positions(keys)
    keys.map { |key| key['skill'.length].to_i }
  end

  def merge_skills(existing_skills, new_skills, positions)
    new_skills.each_with_index do |skill, index|
      existing_skills = place_skill(existing_skills, skill, positions[index])
    end

    existing_skills
  end

  def place_skill(existing_skills, skill, position)
    # Test if skill will exceed allowances of skill types
    skill_type = skill.sub ? 'sub' : 'emp'
    raise Api::V1::TooManySkillsOfTypeError.new(skill_type: skill_type) unless can_add_skill_of_type?(existing_skills, position, skill_type)

    if existing_skills[position]
      value = existing_skills.compact.detect { |_, value| value && value.id == skill.id }
      old_position = existing_skills.key(value[1]) if value

      if old_position
        existing_skills = swap_skills(existing_skills, skill, position, old_position)
      else
        existing_skills[position] = skill
      end
    else
      existing_skills[position] = skill
    end

    existing_skills
  end

  def swap_skills(skills, new_skill, position1, position2)
    # Check desired position for a skill
    displaced_skill = skills[position1] if skills[position1].present?

    # Put skill in new position
    skills[position1] = new_skill
    skills[position2] = displaced_skill

    skills
  end

  def can_add_skill_of_type?(skills, position, type)
    return true unless LIMITED_ROWS.include?(@party.job.row) && skills.values.compact.length.positive?

    skills_to_check = skills.compact.reject { |key, _| key == position }
    skills_to_check.values.count { |value| value.send(type) } + 1 <= MAX_SKILLS_OF_TYPE
  end
end
