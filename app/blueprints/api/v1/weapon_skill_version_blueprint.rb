# frozen_string_literal: true

module Api
  module V1
    class WeaponSkillVersionBlueprint < ApiBlueprint
      # name comes from the canonical Skill; description is the tier's own text,
      # else the skill's (WeaponSkills::VersionText). Projecting them here keeps the
      # version shape consistent with CharacterSkillVersionBlueprint for frontend reuse.
      field(:name) { |version| { en: version.name_en, ja: version.name_jp } }
      field(:description) do |version|
        { en: WeaponSkills::VersionText.for(version, :en), ja: WeaponSkills::VersionText.for(version, :jp) }
      end

      # The same text as display segments ({ text:, strong:, tooltip: }), with the wiki
      # markup resolved against the weapon's element (WeaponSkills::WikiMarkup).
      field(:description_segments) do |version|
        element = version.weapon_skill&.weapon&.element
        %i[en ja].to_h do |locale|
          [locale, WeaponSkills::WikiMarkup.segments(WeaponSkills::VersionText.for(version, locale),
                                                     element: element, locale: locale)]
        end
      end

      # Normalized CDN icon stem (internal element numbering) — the frontend
      # builds /weapon-skill-icons/{locale}/{stem}.png from it. The raw wiki
      # icon name is intentionally not exposed.
      field :icon_stem

      fields :ordinal, :unlock_level, :min_uncap, :transcendence_stage,
             :skill_modifier, :skill_series, :skill_size,
             :main_hand_only, :mc_only, :scales_with_skill_level

      # Curated classification (what the version editor writes). skill_* above
      # is the reparse-derived value; resolved = override, else derived.
      fields :modifier_override, :series_override, :size_override, :suppressed_boosts,
             :overrides_edited_at

      # The classification the calculator uses (WeaponSkillVersion#resolved_*). A
      # resolved_modifier of nil with a "none" override means "no family"; it doesn't
      # fall back to skill_modifier.
      fields :resolved_modifier, :resolved_series, :resolved_size

      association :skill, blueprint: SkillBlueprint
    end
  end
end
