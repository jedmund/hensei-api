# frozen_string_literal: true

namespace :granblue do
  desc "Extract grid-affecting effects from character SUPPORT skills into skill_effects (weapon_skill_boost rows)"
  task extract_character_grid_effects: :environment do
    require Rails.root.join("lib/granblue/extractors/character_grid_effect_extractor")
    ex = Granblue::Extractors::CharacterGridEffectExtractor.new

    versions = CharacterSkillVersion
               .joins(character_skill: :character)
               .left_joins(:skill_effects)
               .where(character_skills: { kind: "support" })
               .where(
                 "character_skill_versions.description_en ILIKE :weapon OR " \
                 "character_skill_versions.description_en ILIKE :effects OR " \
                 "skill_effects.effect_type = :effect_type",
                 weapon: "%weapon skills%", effects: "%skill effects%",
                 effect_type: "weapon_skill_boost"
               )
               .distinct

    created = 0
    matched = 0
    versions.find_each do |v|
      element = Granblue::Extractors::CharacterGridEffectExtractor::CHARACTER_ELEMENT_BY_ID[
        v.character_skill.character.element
      ]
      effects = element.present? ? ex.extract(v.description_en, element: element) : []

      # idempotent: replace this version's weapon_skill_boost rows
      v.skill_effects.effect_weapon_skill_boost.destroy_all
      next if effects.empty?

      matched += 1
      next_ordinal = v.skill_effects.maximum(:ordinal).to_i
      effects.each_with_index do |attrs, i|
        v.skill_effects.create!(attrs.merge(ordinal: next_ordinal + i + 1, raw: v.description_en.to_s[0, 240]))
        created += 1
      end
    end
    puts "weapon_skill_boost effects: #{created} rows across #{matched} support skills"
  end
end
