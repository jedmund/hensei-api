# frozen_string_literal: true

module Api
  module V1
    class WeaponSkillVersionBlueprint < ApiBlueprint
      # name/description are delegated to the canonical Skill (not duplicated in
      # the DB); projecting them here keeps the version shape consistent with
      # CharacterSkillVersionBlueprint for frontend reuse.
      field(:name) { |version| { en: version.name_en, ja: version.name_jp } }
      field(:description) { |version| { en: version.description_en, ja: version.description_jp } }

      # Normalized CDN icon stem (internal element numbering) — the frontend
      # builds /weapon-skill-icons/{locale}/{stem}.png from it. The raw wiki
      # icon name is intentionally not exposed.
      field :icon_stem

      fields :ordinal, :unlock_level, :min_uncap, :transcendence_stage,
             :skill_modifier, :skill_series, :skill_size,
             :main_hand_only, :mc_only, :scales_with_skill_level

      association :skill, blueprint: SkillBlueprint
    end
  end
end
