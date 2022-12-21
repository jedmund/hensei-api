# frozen_string_literal: true

module Api
  module V1
    class PartyBlueprint < ApiBlueprint
      view :preview do
        fields :id, :name, :element, :shortcode, :favorited, :extra, :created_at, :updated_at

        association :raid,
                    blueprint: RaidBlueprint

        association :job,
                    blueprint: JobBlueprint

        association :weapons,
                    blueprint: GridWeaponBlueprint,
                    view: :nested
      end

      view :full do
        include_view :preview
        fields :description, :extra

        field :job_skills do |job|
          {
            '0' => !job.skill0.nil? ? JobSkillBlueprint.render_as_hash(job.skill0) : nil,
            '1' => !job.skill1.nil? ? JobSkillBlueprint.render_as_hash(job.skill1) : nil,
            '2' => !job.skill2.nil? ? JobSkillBlueprint.render_as_hash(job.skill2) : nil,
            '3' => !job.skill3.nil? ? JobSkillBlueprint.render_as_hash(job.skill3) : nil
          }
        end

        association :characters,
                    blueprint: GridCharacterBlueprint,
                    view: :nested

        association :summons,
                    blueprint: GridSummonBlueprint,
                    view: :nested
      end
    end
  end
end
