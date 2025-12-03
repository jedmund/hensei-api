# frozen_string_literal: true

module Api
  module V1
    class CollectionArtifactBlueprint < ApiBlueprint
      identifier :id

      fields :element, :level, :nickname, :created_at, :updated_at

      # Proficiency is only present on quirk artifacts
      field :proficiency, if: ->(_field, obj, _options) { obj.proficiency.present? }

      field :skills do |obj|
        [obj.skill1, obj.skill2, obj.skill3, obj.skill4].map do |skill|
          next nil if skill.blank? || skill == {}

          {
            modifier: skill['modifier'],
            strength: skill['strength'],
            level: skill['level']
          }
        end
      end

      association :artifact, blueprint: ArtifactBlueprint

      view :full do
        association :artifact, blueprint: ArtifactBlueprint
      end
    end
  end
end
