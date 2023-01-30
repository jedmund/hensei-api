# frozen_string_literal: true

module Api
  module V1
    class JobAccessoryBlueprint < ApiBlueprint
      field :name do |skill|
        {
          en: skill.name_en,
          ja: skill.name_jp
        }
      end

      association :job,
                  name: :job,
                  blueprint: JobBlueprint

      fields :granblue_id, :rarity, :release_date
    end
  end
end
