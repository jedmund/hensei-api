# frozen_string_literal: true

module Api
  module V1
    class JobSkillBlueprint < ApiBlueprint
      field :name do |skill|
        {
          en: skill.name_en,
          ja: skill.name_jp
        }
      end

      association :job,
                  name: :job,
                  blueprint: JobBlueprint

      fields :slug, :color, :main, :base, :sub, :emp, :order
    end
  end
end
