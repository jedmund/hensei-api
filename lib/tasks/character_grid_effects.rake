# frozen_string_literal: true

namespace :granblue do
  desc "Extract grid-affecting effects from character SUPPORT skills into skill_effects (weapon_skill_boost rows)"
  task extract_character_grid_effects: :environment do
    require Rails.root.join("lib/granblue/extractors/character_grid_effect_extractor")
    ex = Granblue::Extractors::CharacterGridEffectExtractor.new

    versions = CharacterSkillVersion
               .joins(:character_skill)
               .where(character_skills: { kind: "support" })
               .where("character_skill_versions.description_en ILIKE ?", "%weapon skills%")

    created = 0
    skills = 0
    versions.find_each do |v|
      effects = ex.extract(v.description_en)
      next if effects.empty?

      skills += 1
      # idempotent: replace this version's weapon_skill_boost rows
      v.skill_effects.effect_weapon_skill_boost.destroy_all
      effects.each_with_index do |attrs, i|
        v.skill_effects.create!(attrs.merge(ordinal: 1000 + i, raw: v.description_en.to_s[0, 240]))
        created += 1
      end
    end
    puts "weapon_skill_boost effects: #{created} rows across #{skills} support skills"
  end
end
