# frozen_string_literal: true

module Api
  module V1
    class CharacterSkillBlueprint < ApiBlueprint
      fields :kind, :position

      association :character_skill_versions, blueprint: CharacterSkillVersionBlueprint, name: :versions
    end
  end
end
