# frozen_string_literal: true

module Api
  module V1
    class GridArtifactBlueprint < ApiBlueprint
      fields :element, :level, :reroll_slot

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

      # Include grade and recommendation by default
      field :grade do |obj|
        ArtifactGrader.new(obj).grade
      end

      view :nested do
        association :artifact, blueprint: ArtifactBlueprint
      end

      view :full do
        include_view :nested
        association :grid_character, blueprint: GridCharacterBlueprint
      end

      view :destroyed do
        fields :created_at, :updated_at
      end
    end
  end
end
