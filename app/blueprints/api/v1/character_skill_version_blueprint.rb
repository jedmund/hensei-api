# frozen_string_literal: true

module Api
  module V1
    class CharacterSkillVersionBlueprint < ApiBlueprint
      field(:name) { |version| { en: version.name_en, ja: version.name_jp } }
      field(:description) { |version| { en: version.description_en, ja: version.description_jp } }
      # The English description as display segments ({ text:, strong:, tooltip:, effect:, skill: });
      # effect is the ordinal of one of this version's skill_effects. Japanese has none yet.
      field(:description_segments) { |version| { en: version.description_segments, ja: nil } }

      fields :icon, :game_icon, :type_color, :cooldown, :initial_cooldown, :duration_value, :duration_unit,
             :variant_role, :ordinal, :unlock_level, :enhance_levels, :min_uncap,
             :transcendence_stage, :trigger_type, :trigger_value,
             :cant_recast, :one_time_use, :auto_activate, :mimicable, :targets_all

      association :skill_effects, blueprint: SkillEffectBlueprint
    end
  end
end
