# frozen_string_literal: true

module Api
  module V1
    class SkillEffectBlueprint < ApiBlueprint
      fields :ordinal, :effect_type, :target, :amount, :amount_max,
             :duration_value, :duration_unit, :accuracy, :stacking_frame,
             :damage_pct, :hit_count, :damage_cap, :damage_element, :heal_pct, :heal_cap

      association :status, blueprint: StatusBlueprint
    end
  end
end
