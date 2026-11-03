# frozen_string_literal: true

module Api
  module V1
    # A key's skill on one weapon, in the shape of weapon skill versions (name, description,
    # description_segments, icon_stem, the tier fields) so clients draw it like any other.
    module WeaponKeySkillBlueprint
      module_function

      def versions(key_skill, weapon)
        Array(key_skill&.versions).each_with_index.map do |v, ordinal|
          description = v['description_en']
          {
            name: { en: v['name_en'], ja: nil },
            description: { en: description, ja: nil },
            description_segments: {
              en: WeaponSkills::WikiMarkup.segments(description, element: weapon.element, locale: :en)
            },
            icon_stem: v['icon'],
            ordinal: ordinal,
            unlock_level: v['unlock_level'],
            min_uncap: v['min_uncap'],
            transcendence_stage: v['transcendence_stage']
          }
        end
      end
    end
  end
end
