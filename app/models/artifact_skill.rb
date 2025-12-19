# frozen_string_literal: true

class ArtifactSkill < ApplicationRecord
  # Enums
  enum :skill_group, { group_i: 1, group_ii: 2, group_iii: 3 }
  enum :polarity, { positive: 'positive', negative: 'negative' }

  # Validations
  validates :skill_group, presence: true
  validates :modifier, presence: true, uniqueness: { scope: :skill_group }
  validates :name_en, presence: true
  validates :name_jp, presence: true
  validates :base_values, presence: true
  validates :polarity, presence: true

  # Scopes
  scope :for_slot, ->(slot) {
    case slot
    when 1, 2 then group_i
    when 3 then group_ii
    when 4 then group_iii
    end
  }

  # Class methods for caching skill lookups
  class << self
    def cached_skills
      @cached_skills ||= all.index_by { |s| [s.skill_group, s.modifier] }
    end

    def cached_by_name
      @name_cache ||= begin
        cache = {}
        all.each do |skill|
          cache[skill.name_en] = skill
          cache[skill.name_jp] = skill
        end
        cache
      end
    end

    def find_skill(group, modifier)
      # Convert group number to enum key
      group_key = case group
                  when 1 then 'group_i'
                  when 2 then 'group_ii'
                  when 3 then 'group_iii'
                  else group.to_s
                  end
      cached_skills[[group_key, modifier]]
    end

    def find_by_name(name)
      cached_by_name[name]
    end

    def clear_cache!
      @cached_skills = nil
      @name_cache = nil
    end
  end

  # Calculate the current value of a skill given base strength and skill level
  # @param base_strength [Numeric] The base strength value of the skill
  # @param skill_level [Integer] The current skill level (1-5)
  # @return [Numeric, nil] The calculated value
  def calculate_value(base_strength, skill_level)
    return base_strength if growth.nil?

    base_strength + (growth * (skill_level - 1))
  end

  # Format a value with the appropriate suffix
  # @param value [Numeric] The value to format
  # @param locale [Symbol] :en or :jp
  # @return [String] The formatted value with suffix
  def format_value(value, locale = :en)
    suffix = locale == :jp ? suffix_jp : suffix_en
    "#{value}#{suffix}"
  end

  # Check if a strength value is valid for this skill
  # @param strength [Numeric] The strength value to validate
  # @return [Boolean]
  def valid_strength?(strength)
    return true if base_values.include?(nil) # Unknown values are always valid

    base_values.include?(strength)
  end

  # Get the base strength value for a given quality tier
  # @param quality [Integer] The quality tier (1-5)
  # @return [Numeric, nil] The base strength value
  def strength_for_quality(quality)
    return nil if base_values.nil? || !base_values.is_a?(Array) || base_values.empty?

    # Quality 1-5 maps to index 0-4
    index = (quality - 1).clamp(0, base_values.size - 1)
    base_values[index]
  end
end
