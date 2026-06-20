# frozen_string_literal: true

module GridDamage
  # Builds the Phase 1/2 contributions from a party's weapon_skill_DATA: for each grid
  # weapon's active skill version, evaluate each scaling row at the battle state and emit
  # an Aggregator::Contribution. (The conditional/special track is GridDamage::Effects.)
  module WeaponContributions
    module_function

    def for_party(party, state: {})
      hp = state.fetch(:hp_percent, 100).to_f
      turn = state.fetch(:turn, 1).to_i
      out = []
      party.weapons.includes(weapon: { weapon_skills: :weapon_skill_versions }).each do |gw|
        w = gw.weapon
        next unless w

        skill_level = w.max_skill_level || 15
        w.weapon_skills.each do |ws|
          v = ws.active_version(uncap_level: gw.uncap_level.to_i, transcendence_step: gw.transcendence_step.to_i)
          next unless v # description-derived versions resolve via version-linked data (no modifier needed)

          # The frame is the weapon's series (normal/omega/ex/…); for aura-word-less special
          # weapons (Dark Opus, Draconic) it comes from the weapon's identity. Never use the
          # data row's shared `normal_omega` designation as a frame.
          frame = FrameResolver.frame_for(w, v)
          v.weapon_skill_data.each do |d|
            value = Scaling.value(d, skill_level: skill_level, hp_percent: hp, turn: turn)
            out << Aggregator::Contribution.new(
              boost_type: d.boost_type, series: frame,
              value: value, main_hand_only: v.main_hand_only, mainhand: gw.mainhand
            )
          end
        end
      end
      out
    end
  end
end
