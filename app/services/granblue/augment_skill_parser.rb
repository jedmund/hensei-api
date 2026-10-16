# frozen_string_literal: true

module Granblue
  ##
  # Parses a weapon's augment skills (AX rolls, or an Odious weapon's befoulment,
  # permeation and exorcision level) and skill level from the game's weapon
  # `param` data. Shared by party
  # import (Processors::WeaponProcessor) and collection import (WeaponImportService)
  # so both store the same values.
  #
  # The game sends augment skills as an array of skill arrays:
  #   "augment_skill_info": [[{ "skill_id": 1589, "effect_value": "2.5", "show_value": "+2.5%", "depth": null }, ...]]
  # and marks Odious weapons with:
  #   "odiant": { "is_odiant_weapon": true, "exorcision_level": 5, "max_exorcision_level": 5, ... }
  # An Odious weapon's single augment entry is its befoulment; its `depth` is the
  # permeation level. `effect_value` is the magnitude; the sign is only in `show_value`.
  # Every weapon carries `"skill_level": "15"`.
  #
  # Modifiers are resolved by WeaponStatModifier#game_skill_id. Unknown ids are
  # logged and skipped.
  class AugmentSkillParser
    MAX_EXORCISM_LEVEL = 5
    PERMEATION_RANGE = (1..6)
    SKILL_LEVEL_RANGE = (1..25)

    # @param log_tag [String] prefix for log lines, e.g. "WeaponProcessor"
    def initialize(log_tag:)
      @log_tag = log_tag
      @modifier_cache = {}
    end

    ##
    # Returns the attributes for a weapon's game param data: befoulment,
    # permeation and exorcism level for Odious weapons, AX skills otherwise,
    # plus the skill level. Values the game didn't send are left out, so
    # merging the result never clears a stored value.
    #
    # @param param [Hash] the game's weapon `param` hash
    # @return [Hash] attributes to assign (empty if there are none)
    def attributes(param)
      return {} unless param.is_a?(Hash)

      attrs = if odious?(param)
                befoulment_attrs(param['augment_skill_info']).merge(exorcism_level: exorcism_level(param))
              else
                ax_attrs(param['augment_skill_info'])
              end

      level = skill_level(param)
      attrs[:skill_level] = level if level
      attrs
    end

    # @param param [Hash] the game's weapon `param` hash
    # @return [Boolean] whether the game marks this weapon as Odious
    def odious?(param)
      odiant = param['odiant']
      odiant.is_a?(Hash) && odiant['is_odiant_weapon'] == true
    end

    ##
    # @param augment_skill_info [Array] the game's augment skill data
    # @return [Hash] ax_modifier{1,2}_id / ax_strength{1,2} for the parsed slots
    def ax_attrs(augment_skill_info)
      skills = skill_list(augment_skill_info)
      attrs = {}

      skills.first(2).each_with_index do |skill, index|
        parsed = parse_skill(skill)
        next unless parsed

        attrs[:"ax_modifier#{index + 1}_id"] = parsed[:modifier_id]
        attrs[:"ax_strength#{index + 1}"] = parsed[:strength]
      end

      attrs
    end

    ##
    # Odious weapons carry a single befoulment in augment_skill_info.
    #
    # @param augment_skill_info [Array] the game's augment skill data
    # @return [Hash] befoulment_modifier_id / befoulment_strength, plus
    #   befoulment_permeation when the game sent a depth; or empty
    def befoulment_attrs(augment_skill_info)
      skill = skill_list(augment_skill_info).first
      parsed = parse_skill(skill)
      return {} unless parsed

      attrs = { befoulment_modifier_id: parsed[:modifier_id], befoulment_strength: parsed[:strength] }
      permeation = integer_in(skill['depth'], PERMEATION_RANGE)
      attrs[:befoulment_permeation] = permeation if permeation
      attrs
    end

    private

    def skill_level(param)
      integer_in(param['skill_level'], SKILL_LEVEL_RANGE)
    end

    # @return [Integer, nil] the value as an integer when it is one within range
    def integer_in(value, range)
      integer = Integer(value.to_s, 10, exception: false)
      integer if integer && range.cover?(integer)
    end

    def exorcism_level(param)
      param['odiant']['exorcision_level'].to_i.clamp(0, MAX_EXORCISM_LEVEL)
    end

    def skill_list(augment_skill_info)
      return [] unless augment_skill_info.is_a?(Array)

      skills = augment_skill_info.first
      skills.is_a?(Array) ? skills : []
    end

    # @param skill [Hash, nil] a single skill with skill_id, effect_value, show_value
    # @return [Hash, nil] { modifier_id:, strength: }
    def parse_skill(skill)
      return nil unless skill.is_a?(Hash) && skill['skill_id'].present?

      game_skill_id = skill['skill_id'].to_i
      modifier = find_modifier(game_skill_id)

      unless modifier
        Rails.logger.warn(
          "[#{@log_tag}] Unknown augment skill_id=#{game_skill_id} " \
          "icon=#{skill['augment_skill_icon_image']}"
        )
        return nil
      end

      strength = Granblue::AugmentStrength.parse(skill['effect_value'], skill['show_value'])
      return nil unless strength

      { modifier_id: modifier.id, strength: strength }
    end

    def find_modifier(game_skill_id)
      return @modifier_cache[game_skill_id] if @modifier_cache.key?(game_skill_id)

      @modifier_cache[game_skill_id] = WeaponStatModifier.find_by(game_skill_id: game_skill_id)
    end
  end
end
