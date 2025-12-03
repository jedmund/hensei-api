# frozen_string_literal: true

##
# Grades artifacts based on skill selection, base strength, and synergy.
# Provides recommendations: scrap, keep, or reroll with target line.
#
# @example
#   grader = ArtifactGrader.new(collection_artifact)
#   result = grader.grade
#   # => { letter: "A", score: 85, recommendation: { action: :keep, ... } }
#
class ArtifactGrader
  # Skill priority tiers by group (modifier => tier)
  # Based on community ratings for burst, HL, and general use cases
  SKILL_TIERS = {
    group_i: {
      # Ideal (Good): Triple Attack Rate (8), Debuff Success Rate (13)
      ideal: [8, 13],
      # Good (Nice to have): Elemental ATK (5)
      good: [5],
      # Neutral (Meh/Situational): ATK (1), HP (2), CA DMG (3), DEF (9),
      #                            Superior Element Reduction (10), Dodge Rate (11), Healing (12)
      neutral: [1, 2, 3, 9, 10, 11, 12],
      # Bad (Garbage): Skill DMG (4), Critical Hit Rate (6), Double Attack Rate (7), Debuff Resistance (14)
      bad: [4, 6, 7, 14]
    },
    group_ii: {
      # Ideal (Good): NA Cap (1), Skill Cap (2), CA Cap (3), Crit DMG Cap (5), Supp NA (9), Supp Skill (10),
      #               Supp CA (11), TA at 50%+ (13), 100% HP Amplify (14), HP/-DEF (15)
      ideal: [1, 2, 3, 5, 9, 10, 11, 13, 14, 15],
      # Good (Situational): Special CA Cap (4), NA/Skill/CA tradeoffs (6,7,8)
      good: [4, 6, 7, 8],
      # Neutral (Meh/Very situational): Chain Amplify (12), DMG reduction <50% (16),
      #                                  Debuff removal (19), Dispel cancel (20)
      neutral: [12, 16, 19, 20],
      # Bad (Garbage): Regeneration (17), Turn-Based DMG Reduction (18)
      bad: [17, 18]
    },
    group_iii: {
      # Ideal (Good): 10+ turn skill amplified (11), Stackable Supp Skill DMG (22)
      ideal: [11, 22],
      # Good (Situationally core/Nice to have/Free stuff): First-slot CD (7), Stackable Cap Up (10),
      #       CA Supp DMG (13), EXP (27), Drop rate (28), Earrings (29)
      good: [7, 10, 13, 27, 28, 29],
      # Neutral (Situational/Meh/Very situational): Random buffs start (2), HP consumed/Cap Up (3),
      #          KO buffs (4), Switch amplified (5), HP restore (6), Debuff skill amplify (8),
      #          Non-attacker buffs (14), Shield (17), 6-hit Flurry (18), Targeted bonus (19),
      #          Flurry 3-hit (20), Plain DMG (21), Potion FC (24), Armored (25), Sub debuff (26)
      neutral: [1, 2, 3, 4, 5, 6, 8, 14, 17, 18, 19, 20, 21, 24, 25, 26],
      # Bad (Garbage/Probably garbage): Healing skill bonus (9), Linked skill (12),
      #      Buff removal (15), Turn skip (16), Single attack buffs (23)
      bad: [9, 12, 15, 16, 23]
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
  # Based on actual skill modifiers from artifact_skills.json
  SYNERGY_PAIRS = [
    # Triple Attack Rate (I-8) + TA at 50%+ HP (II-13)
    [[:group_i, 8], [:group_ii, 13]],
    # Triple Attack Rate (I-8) + Supplemental N.A. DMG (II-9)
    [[:group_i, 8], [:group_ii, 9]],
    # Elemental ATK (I-5) + Crit DMG Cap (II-5)
    [[:group_i, 5], [:group_ii, 5]],
    # N.A. DMG Cap (II-1) + Supplemental N.A. DMG (II-9)
    [[:group_ii, 1], [:group_ii, 9]],
    # Skill DMG Cap (II-2) + Supplemental Skill DMG (II-10)
    [[:group_ii, 2], [:group_ii, 10]],
    # C.A. DMG Cap (II-3) + Supplemental C.A. DMG (II-11)
    [[:group_ii, 3], [:group_ii, 11]],
    # Skill DMG Cap (II-2) + Stackable Supp Skill DMG (III-22)
    [[:group_ii, 2], [:group_iii, 22]],
    # 10+ turn skill amplified (III-11) + Skill DMG Cap (II-2)
    [[:group_iii, 11], [:group_ii, 2]]
  ].freeze

  SYNERGY_BONUS = 10

  # Recommendation thresholds
  SCRAP_THRESHOLD = 45        # Score below this = scrap
  KEEP_THRESHOLD = 80         # Score at or above this = keep (no reroll needed)
  # Between SCRAP_THRESHOLD and KEEP_THRESHOLD = reroll

  def initialize(artifact_instance)
    @artifact = artifact_instance
  end

  ##
  # Calculates the full grade for the artifact.
  #
  # @return [Hash] Grade result with letter, score, breakdown, lines, and recommendation
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
      recommendation: build_recommendation(overall, lines)
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
      recommendation: nil,
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

  ##
  # Builds a recommendation based on overall score and line analysis.
  # Actions: :scrap, :keep, or :reroll
  #
  # @param overall [Integer] The overall artifact score
  # @param lines [Array<Hash>] The scored lines
  # @return [Hash] Recommendation with action and details
  def build_recommendation(overall, lines)
    valid_lines = lines.compact
    return nil if valid_lines.empty?

    # Check for immediate scrap conditions
    if should_scrap?(overall, valid_lines)
      return scrap_recommendation(overall, valid_lines)
    end

    # Check if artifact is good enough to keep
    if should_keep?(overall, valid_lines)
      return keep_recommendation(overall, valid_lines)
    end

    # Otherwise, recommend rerolling the weakest line
    reroll_recommendation(overall, valid_lines)
  end

  def should_scrap?(overall, lines)
    # Scrap if overall score is very low
    return true if overall < SCRAP_THRESHOLD

    # Scrap if we have a bad skill and multiple neutral/bad skills
    bad_count = lines.count { |l| l[:tier] == :bad }
    neutral_or_worse = lines.count { |l| %i[bad neutral].include?(l[:tier]) }

    return true if bad_count >= 1 && neutral_or_worse >= 3

    # Scrap if no ideal or good skills at all
    good_or_better = lines.count { |l| %i[ideal good].include?(l[:tier]) }
    return true if good_or_better.zero?

    false
  end

  def should_keep?(overall, lines)
    # Keep if score is high enough
    return true if overall >= KEEP_THRESHOLD

    # Keep if all lines are ideal tier (even with mediocre rolls)
    ideal_count = lines.count { |l| l[:tier] == :ideal }
    return true if ideal_count == lines.size

    # Keep if we have 3+ ideal skills with good synergy
    return true if ideal_count >= 3 && overall >= 75

    false
  end

  def scrap_recommendation(overall, lines)
    bad_lines = lines.select { |l| l[:tier] == :bad }
    neutral_lines = lines.select { |l| l[:tier] == :neutral }

    reason = if overall < SCRAP_THRESHOLD
               'Overall score is too low to justify investment'
             elsif bad_lines.any?
               bad_names = bad_lines.map { |l| skill_name_for_line(l) }.join(', ')
               "Contains detrimental skill(s): #{bad_names}"
             else
               'No valuable skills worth building around'
             end

    {
      action: :scrap,
      reason: reason,
      details: {
        bad_skills: bad_lines.map { |l| skill_name_for_line(l) },
        neutral_skills: neutral_lines.map { |l| skill_name_for_line(l) }
      }
    }
  end

  def keep_recommendation(overall, lines)
    ideal_lines = lines.select { |l| l[:tier] == :ideal }
    good_lines = lines.select { |l| l[:tier] == :good }

    reason = if overall >= KEEP_THRESHOLD
               'Artifact is well-optimized'
             elsif ideal_lines.size == lines.size
               'All skills are ideal tier'
             else
               'Strong skill combination with good synergy'
             end

    {
      action: :keep,
      reason: reason,
      details: {
        ideal_skills: ideal_lines.map { |l| skill_name_for_line(l) },
        good_skills: good_lines.map { |l| skill_name_for_line(l) }
      }
    }
  end

  def reroll_recommendation(overall, lines)
    # Find the weakest line
    weakest = lines.min_by { |l| l[:combined_score] }

    # Calculate potential gain if rerolled to ideal with max strength
    potential_ideal_score = (TIER_POINTS[:ideal] * 0.7 + 100 * 0.3).round
    potential_gain = potential_ideal_score - weakest[:combined_score]

    # Get ideal skills for this slot's group
    ideal_skills = ideal_skills_for_slot(weakest[:slot])

    {
      action: :reroll,
      reason: reroll_reason(weakest),
      slot: weakest[:slot],
      current_skill: skill_name_for_line(weakest),
      current_tier: weakest[:tier],
      potential_gain: potential_gain,
      priority: reroll_priority(weakest, potential_gain),
      target_skills: ideal_skills
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
        'Weakest line is already well-optimized'
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
