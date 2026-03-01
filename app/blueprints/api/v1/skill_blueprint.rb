# frozen_string_literal: true

module Api
  module V1
    class SkillBlueprint < ApiBlueprint
      field :name do |s|
        {
          en: s.name_en,
          ja: s.name_jp
        }
      end

      field :description do |s|
        {
          en: s.description_en,
          ja: s.description_jp
        }
      end

      field :skill_type
    end
  end
end
