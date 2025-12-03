# frozen_string_literal: true

##
# Grades artifacts based on skill selection, base strength, and synergy.
# Also provides reroll recommendations.
#
# @example
#   grader = ArtifactGrader.new(collection_artifact)
#   result = grader.grade
#   # => { letter: "A", score: 85, ... }
#
class ArtifactGrader
  # Skill priority tiers by group (modifier => tier)
  SKILL_TIERS = {
    group_i: {
      # Ideal: ATK (1), Elemental ATK (5), Triple Attack Rate (8)
      ideal: [1, 5, 8],
      # Good: HP (2), DEF (3), Superior Element Reduction (4)
      good: [2, 3, 4],
      neutral: [6, 7, 9, 10, 11, 12, 13, 14],
      bad: []
    },
    group_ii: {
      # Ideal: Crit DMG Cap (4), Supp Skill DMG (13), Supp NA DMG (14), TA at 50%+ HP (17)
      ideal: [4, 13, 14, 17],
      # Good: Skill Cap (1), NA Cap (2), CA Cap (3), Special CA Cap (5), Supp CA DMG (15), HP boost/-DEF (20)
      good: [1, 2, 3, 5, 15, 20],
      neutral: [6, 7, 8, 9, 10, 11, 12, 16, 18, 19],
      bad: []
    },
    group_iii: {
      # Ideal: Earring finder (29), 10+ turn skill amplified (23)
      ideal: [29, 23],
      # Good: First-slot skill CD reduction (19)
      good: [19],
      neutral: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 20, 21, 22, 24, 25, 26, 27],
      # Bad: Turn skip (28)
      bad: [28]
    }
  }.freeze

  # Points awarded per tier
  TIER_POINTS = {
    ideal: 100,
    good: 70,
    neutral: 50,
    bad: 10
  }.freeze

  # Letter grade thresholds
  GRADE_THRESHOLDS = {
    95 => 'S',
    85 => 'A',
    70 => 'B',
    55 => 'C',
    40 => 'D'
  }.freeze

  # Synergy bonuses: pairs of (group, modifier) that work well together
  SYNERGY_PAIRS = [
    # ATK + Crit DMG Cap
    [[:group_i, 1], [:group_ii, 4]],
    # ATK + Supp NA DMG
    [[:group_i, 1], [:group_ii, 14]],
    # Triple Attack + Supp NA DMG
    [[:group_i, 8], [:group_ii, 14]],
    # Triple Attack + TA at 50%+ HP
    [[:group_i, 8], [:group_ii, 17]],
    # Elemental ATK + Crit DMG Cap
    [[:group_i, 5], [:group_ii, 4]],
    # Skill Cap + Supp Skill DMG
    [[:group_ii, 1], [:group_ii, 13]],
    # CA Cap + Supp CA DMG
    [[:group_ii, 3], [:group_ii, 15]]
  ].freeze

  SYNERGY_BONUS = 10

  def initialize(artifact_instance)
    @artifact = artifact_instance
  end

  ##
  # Calculates the full grade for the artifact.
  #
  # @return [Hash] Grade result with letter, score, breakdown, lines, and reroll recommendation
  def grade
    return quirk_grade if quirk_artifact?

    lines = calculate_line_scores
    selection_score = skill_selection_score(lines)
    strength_score = base_strength_score(lines)
    synergy = synergy_score(lines)

    overall = weighted_score(selection_score, strength_score, synergy)

    {
      letter: letter_grade(overall),
      score: overall,
      breakdown: {
        skill_selection: selection_score,
        base_strength: strength_score,
        synergy: synergy
      },
      lines: lines,
      reroll_recommendation: reroll_recommendation(lines)
    }
  end

  private

  def quirk_artifact?
    @artifact.respond_to?(:quirk_artifact?) ? @artifact.quirk_artifact? : @artifact.artifact&.quirk?
  end

  def quirk_grade
    {
      letter: nil,
      score: nil,
      breakdown: nil,
      lines: nil,
      reroll_recommendation: nil,
      note: 'Quirk artifacts cannot be graded'
    }
  end

  def calculate_line_scores
    [
      score_line(1, @artifact.skill1, :group_i),
      score_line(2, @artifact.skill2, :group_i),
      score_line(3, @artifact.skill3, :group_ii),
      score_line(4, @artifact.skill4, :group_iii)
    ]
  end

  def score_line(slot, skill_data, group)
    return nil if skill_data.blank? || skill_data == {}

    modifier = skill_data['modifier']
    strength = skill_data['strength']
    level = skill_data['level']

    return nil unless modifier

    tier = tier_for_modifier(group, modifier)
    tier_score = TIER_POINTS[tier]
    str_score = score_base_strength(group, modifier, strength)

    combined = (tier_score * 0.7 + str_score * 0.3).round

    {
      slot: slot,
      group: group,
      modifier: modifier,
      tier: tier,
      tier_score: tier_score,
      strength_score: str_score,
      combined_score: combined,
      level: level
    }
  end

  def tier_for_modifier(group, modifier)
    tiers = SKILL_TIERS[group]
    return :ideal if tiers[:ideal].include?(modifier)
    return :good if tiers[:good].include?(modifier)
    return :bad if tiers[:bad].include?(modifier)

    :neutral
  end

  def score_base_strength(group, modifier, strength)
    return 50 if strength.nil?

    skill_def = ArtifactSkill.find_skill(group_number(group), modifier)
    return 50 unless skill_def

    base_values = skill_def.base_values
    return 50 if base_values.blank? || base_values.include?(nil)

    # Find position in base_values array (0-4 for 5 possible values)
    index = base_values.index(strength)
    return 50 unless index

    # Convert to percentage: index 0 = 20%, index 4 = 100%
    ((index + 1) * 20).clamp(0, 100)
  end

  def group_number(group)
    case group
    when :group_i then 1
    when :group_ii then 2
    when :group_iii then 3
    end
  end

  def skill_selection_score(lines)
    valid_lines = lines.compact
    return 0 if valid_lines.empty?

    total = valid_lines.sum { |l| l[:tier_score] }
    (total.to_f / valid_lines.size).round
  end

  def base_strength_score(lines)
    valid_lines = lines.compact
    return 0 if valid_lines.empty?

    total = valid_lines.sum { |l| l[:strength_score] }
    (total.to_f / valid_lines.size).round
  end

  def synergy_score(lines)
    valid_lines = lines.compact
    return 0 if valid_lines.empty?

    # Build a set of (group, modifier) pairs from the artifact
    skill_pairs = valid_lines.map { |l| [l[:group], l[:modifier]] }.to_set

    # Count matching synergy pairs
    matches = SYNERGY_PAIRS.count do |pair|
      pair.all? { |gm| skill_pairs.include?(gm) }
    end

    # Base synergy score + bonus per match
    base = 50
    bonus = matches * SYNERGY_BONUS
    (base + bonus).clamp(0, 100)
  end

  def weighted_score(selection, strength, synergy)
    # Skill selection: 50%, Base strength: 30%, Synergy: 20%
    ((selection * 0.5) + (strength * 0.3) + (synergy * 0.2)).round
  end

  def letter_grade(score)
    GRADE_THRESHOLDS.each do |threshold, letter|
      return letter if score >= threshold
    end
    'F'
  end

  def reroll_recommendation(lines)
    valid_lines = lines.compact
    return nil if valid_lines.empty?

    # Find the weakest line
    weakest = valid_lines.min_by { |l| l[:combined_score] }

    # Calculate potential gain if rerolled to ideal with max strength
    potential_ideal_score = (TIER_POINTS[:ideal] * 0.7 + 100 * 0.3).round
    potential_gain = potential_ideal_score - weakest[:combined_score]

    # Get ideal skills for this slot's group
    ideal_skills = ideal_skills_for_slot(weakest[:slot])

    {
      slot: weakest[:slot],
      current_modifier: weakest[:modifier],
      current_tier: weakest[:tier],
      current_score: weakest[:combined_score],
      potential_score: potential_ideal_score,
      potential_gain: potential_gain,
      target_skills: ideal_skills,
      reason: reroll_reason(weakest),
      priority: reroll_priority(weakest, potential_gain)
    }
  end

  def ideal_skills_for_slot(slot)
    group = slot <= 2 ? :group_i : (slot == 3 ? :group_ii : :group_iii)
    group_num = group_number(group)

    SKILL_TIERS[group][:ideal].map do |modifier|
      skill = ArtifactSkill.find_skill(group_num, modifier)
      next unless skill

      {
        modifier: modifier,
        name_en: skill.name_en,
        name_jp: skill.name_jp
      }
    end.compact
  end

  def skill_name_for_line(line)
    skill = ArtifactSkill.find_skill(group_number(line[:group]), line[:modifier])
    skill&.name_en || "Skill #{line[:modifier]}"
  end

  def reroll_reason(line)
    skill_name = skill_name_for_line(line)

    case line[:tier]
    when :bad
      "#{skill_name} is a detrimental skill"
    when :neutral
      "#{skill_name} provides minimal value"
    when :good
      if line[:strength_score] < 50
        "#{skill_name} has a low base roll"
      else
        "#{skill_name} could be upgraded to an ideal skill"
      end
    when :ideal
      if line[:strength_score] < 60
        "#{skill_name} is ideal but has a poor base roll"
      else
        'This artifact is already well-optimized'
      end
    end
  end

  def reroll_priority(line, potential_gain)
    if line[:tier] == :bad || potential_gain > 60
      :high
    elsif potential_gain > 30
      :medium
    else
      :low
    end
  end
end
