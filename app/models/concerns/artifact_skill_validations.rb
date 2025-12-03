# frozen_string_literal: true

module ArtifactSkillValidations
  extend ActiveSupport::Concern

  included do
    validate :validate_skill1_group_i
    validate :validate_skill2_group_i
    validate :validate_skill3_group_ii
    validate :validate_skill4_group_iii
    validate :validate_duplicate_skills
    validate :validate_skill_levels_sum, unless: :quirk_artifact?
    validate :validate_quirk_artifact_constraints, if: :quirk_artifact?
  end

  private

  def quirk_artifact?
    artifact&.quirk?
  end

  def validate_skill_in_group(skill_data, group_number, slot_name)
    return if skill_data.blank? || skill_data == {}
    return if quirk_artifact?

    modifier = skill_data['modifier']
    strength = skill_data['strength']
    skill_level = skill_data['level']

    unless modifier && strength && skill_level
      errors.add(slot_name, 'must have modifier, strength, and level')
      return
    end

    skill_def = ArtifactSkill.find_skill(group_number, modifier)
    unless skill_def
      errors.add(slot_name, "has invalid modifier #{modifier}")
      return
    end

    unless (1..5).cover?(skill_level)
      errors.add(slot_name, 'level must be between 1 and 5')
      return
    end

    # Validate strength is a valid base value for this skill
    unless skill_def.valid_strength?(strength)
      errors.add(slot_name, "has invalid base strength #{strength}")
    end
  end

  def validate_skill1_group_i
    validate_skill_in_group(skill1, 1, :skill1)
  end

  def validate_skill2_group_i
    validate_skill_in_group(skill2, 1, :skill2)
  end

  def validate_skill3_group_ii
    validate_skill_in_group(skill3, 2, :skill3)
  end

  def validate_skill4_group_iii
    validate_skill_in_group(skill4, 3, :skill4)
  end

  def validate_duplicate_skills
    return if quirk_artifact?

    # Skills 1 and 2 are both from Group I and cannot have the same modifier
    return if skill1.blank? || skill1 == {} || skill2.blank? || skill2 == {}

    if skill1['modifier'] == skill2['modifier']
      errors.add(:base, 'Skill 1 and Skill 2 cannot have the same modifier')
    end
  end

  def validate_skill_levels_sum
    # For standard artifacts, skill levels must sum to (artifact_level + 3)
    # At level 1: all skills level 1, sum = 4
    # At level 5: skills sum = 8 (distributed among 4 skills)
    return if level.nil?

    skills = [skill1, skill2, skill3, skill4]

    # Skip validation if any skill is empty (incomplete artifact)
    return if skills.any? { |s| s.blank? || s == {} }

    total = skills.sum { |s| s['level'].to_i }
    expected = level + 3

    return if total == expected

    errors.add(:base, "Skill levels must sum to #{expected} for artifact level #{level}, got #{total}")
  end

  def validate_quirk_artifact_constraints
    errors.add(:level, 'must be 1 for quirk artifacts') unless level == 1

    # Quirk artifacts don't store skills
    [skill1, skill2, skill3, skill4].each_with_index do |skill, idx|
      next if skill.blank? || skill == {}

      errors.add(:"skill#{idx + 1}", 'must be empty for quirk artifacts')
    end
  end
end
