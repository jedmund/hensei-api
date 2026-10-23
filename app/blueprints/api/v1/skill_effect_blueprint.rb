# frozen_string_literal: true

module Api
  module V1
    class SkillEffectBlueprint < ApiBlueprint
      # category: buff | debuff | field | special for this effect (D36); the status's own category is its usual one.
      # label: the skill's own name for the status when the wiki links it to another (D57; null = the status name).
      fields :ordinal, :effect_type, :category, :label, :target, :amount, :amount_max,
             :duration_value, :duration_unit, :accuracy, :stacking_frame,
             :damage_pct, :hit_count, :damage_cap, :damage_element, :heal_pct, :heal_cap

      association :status, blueprint: StatusBlueprint
    end
  end
end
