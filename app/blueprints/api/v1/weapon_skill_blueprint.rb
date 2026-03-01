# frozen_string_literal: true

module Api
  module V1
    class WeaponSkillBlueprint < ApiBlueprint
      field :position
      field :uncap_level
      fields :skill_modifier, :skill_series, :skill_size, :unlock_level

      association :skill, blueprint: SkillBlueprint
    end
  end
end
