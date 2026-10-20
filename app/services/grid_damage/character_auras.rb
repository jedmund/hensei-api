# frozen_string_literal: true

module GridDamage
  # Polls a party's members (frontline AND sub) for passive support skills that boost
  # weapon skills (the weapon_skill_boost SkillEffects, e.g. Gabriel's Hudor Arche), and
  # totals them into the per-frame aura for the grid element. These take effect even when
  # the character is a sub ally.
  module CharacterAuras
    module_function

    # → { optimus:, omega: } percent totals.
    def for_party(party, element:)
      totals = { optimus: 0.0, omega: 0.0 }
      # Skills belong to the grid character's own row, so a style shift counts its own
      # support skills, not its base's. Filtered in Ruby to stay on the preload.
      party.characters.includes(character: { character_skills: { character_skill_versions: :skill_effects } }).each do |gc|
        next unless gc.character

        gc.character.character_skills.select(&:support?).each do |cs|
          version = active_version(cs)
          next unless version

          version.skill_effects.each do |e|
            next unless e.effect_weapon_skill_boost? && [element, "all"].include?(e.element)

            totals[:optimus] += e.amount.to_f if e.frame == "normal"
            totals[:omega]   += e.amount.to_f if e.frame == "omega"
          end
        end
      end
      totals
    end

    # The most-uncapped version (support-aura values are fixed across versions; refine to
    # uncap-aware selection if a skill's value ever scales).
    def active_version(character_skill)
      character_skill.character_skill_versions
                     .max_by { |v| [v.min_uncap.to_i, v.transcendence_stage.to_i, v.ordinal.to_i] }
    end
  end
end
