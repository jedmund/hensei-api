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
        [
          [obj.skill1, 1],
          [obj.skill2, 2],
          [obj.skill3, 3],
          [obj.skill4, 4]
        ].map do |skill, slot|
          next nil if skill.blank? || skill == {}

          # Determine skill group based on slot
          group = case slot
                  when 1, 2 then 1  # Group I
                  when 3 then 2     # Group II
                  when 4 then 3     # Group III
                  end

          # Look up skill and compute strength from quality
          modifier = skill['modifier']
          quality = skill['quality'] || 1
          level = skill['level'] || 1

          artifact_skill = ArtifactSkill.find_skill(group, modifier)
          strength = artifact_skill&.strength_for_quality(quality)

          {
            modifier: modifier,
            strength: strength,
            level: level
          }
        end
      end

      field :score do |obj|
        if obj.total_score.present?
          {
            attack: obj.attack_score,
            defense: obj.defense_score,
            special: obj.special_score,
            total: obj.total_score
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
