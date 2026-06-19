# frozen_string_literal: true

module Api
  module V1
    class WeaponSkillBlueprint < ApiBlueprint
      field :position

      association :weapon_skill_versions, blueprint: WeaponSkillVersionBlueprint, name: :versions
    end
  end
end
