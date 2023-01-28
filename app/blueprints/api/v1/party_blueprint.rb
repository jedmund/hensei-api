# frozen_string_literal: true

module Api
  module V1
    class PartyBlueprint < ApiBlueprint
      view :weapons do
        association :weapons,
                    blueprint: GridWeaponBlueprint,
                    view: :nested
      end

      view :summons do
        association :summons,
                    blueprint: GridSummonBlueprint,
                    view: :nested
      end

      view :characters do
        association :characters,
                    blueprint: GridCharacterBlueprint,
                    view: :nested
      end

      view :job_skills do
        field :job_skills do |job|
          {
            '0' => !job.skill0.nil? ? JobSkillBlueprint.render_as_hash(job.skill0) : nil,
            '1' => !job.skill1.nil? ? JobSkillBlueprint.render_as_hash(job.skill1) : nil,
            '2' => !job.skill2.nil? ? JobSkillBlueprint.render_as_hash(job.skill2) : nil,
            '3' => !job.skill3.nil? ? JobSkillBlueprint.render_as_hash(job.skill3) : nil
          }
        end
      end

      view :minimal do
        fields :name, :element, :shortcode, :favorited, :extra,
               :full_auto, :clear_time, :auto_guard, :created_at, :updated_at

        field :remix do |p|
          p.is_remix
        end

        association :raid,
                    blueprint: RaidBlueprint

        association :job,
                    blueprint: JobBlueprint

        association :user,
                    blueprint: UserBlueprint,
                    view: :minimal

        association :remixes,
                    blueprint: PartyBlueprint,
                    view: :minimal
      end

      view :jobs do
        association :job,
                    blueprint: JobBlueprint
        include_view :job_skills
      end

      view :preview do
        include_view :minimal
        include_view :weapons
      end

      view :full do
        include_view :preview
        include_view :summons
        include_view :characters
        include_view :job_skills

        association :accessory,
                    blueprint: JobAccessoryBlueprint
        fields :description, :charge_attack, :button_count, :turn_count, :chain_count
      end

      view :collection do
        include_view :preview
      end

      view :destroyed do
        fields :name, :description, :created_at, :updated_at
      end
    end
  end
end
