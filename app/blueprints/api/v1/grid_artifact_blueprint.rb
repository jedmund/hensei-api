# frozen_string_literal: true

module Api
  module V1
    class GridArtifactBlueprint < ApiBlueprint
      fields :level, :reroll_slot

      field :collection_artifact_id
      field :out_of_sync, if: ->(_field, ga, _options) { ga.collection_artifact_id.present? } do |ga|
        ga.out_of_sync?
      end

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
