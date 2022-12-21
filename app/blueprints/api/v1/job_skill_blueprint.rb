# frozen_string_literal: true

module Api
  module V1
    class JobSkillBlueprint < ApiBlueprint
      fields :id, :slug, :color, :main, :base, :sub, :emp, :order

      association :job,
                  name: :job,
                  blueprint: JobBlueprint

      field :name do |skill|
        {
          en: skill.name_en,
          ja: skill.name_jp
        }
      end
    end
  end
end
