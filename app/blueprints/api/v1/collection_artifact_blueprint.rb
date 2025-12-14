# frozen_string_literal: true

module Api
  module V1
    class CollectionArtifactBlueprint < ApiBlueprint
      identifier :id

      fields :level, :nickname, :reroll_slot, :created_at, :updated_at

      # Return element as integer
      field :element do |obj|
        obj.element_before_type_cast
      end

      # Proficiency is only present on quirk artifacts, return as integer
      field :proficiency, if: ->(_field, obj, _options) { obj.proficiency.present? } do |obj|
        obj.proficiency_before_type_cast
      end

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

      # Include grade and recommendation by default
      field :grade do |obj|
        ArtifactGrader.new(obj).grade
      end

      association :artifact, blueprint: ArtifactBlueprint

      view :full do
        association :artifact, blueprint: ArtifactBlueprint
      end
    end
  end
end
