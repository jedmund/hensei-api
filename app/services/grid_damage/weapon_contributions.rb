# frozen_string_literal: true

module GridDamage
  # Builds the Phase 1/2 contributions from a party's weapon_skill_DATA: for each grid
  # weapon's active skill version, evaluate each scaling row at the battle state and emit
  # an Aggregator::Contribution. (The conditional/special track is GridDamage::Effects.)
  module WeaponContributions
    module_function

    # Series NOT boosted by summons (gbf.wiki/Weapon_Skills + in-game): their skills land on the
    # panel flat, like EX. Their contributions are non-amplifiable.
    NON_SUMMON_BOOSTED_SERIES = %w[bahamut celestial ultima destroyer].freeze

    def for_party(party, state: {})
      hp = state.fetch(:hp_percent, 100).to_f
      turn = state.fetch(:turn, 1).to_i
      out = []
      party.weapons.includes(weapon: { weapon_skills: :weapon_skill_versions }).each do |gw|
        w = gw.weapon
        next unless w

        # Skill level is the ULB max (e.g. SL20) through transcendence stages 0–4, then jumps
        # +5 only at the FINAL stage (transc 5 → SL25). It is not raised per-stage.
        skill_level = (w.max_skill_level || 15) + (gw.transcendence_step.to_i >= 5 ? 5 : 0)
        amplifiable = !NON_SUMMON_BOOSTED_SERIES.include?(w.weapon_series&.slug)
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
              value: value, main_hand_only: v.main_hand_only, mainhand: gw.mainhand,
              amplifiable: amplifiable
            )
          end
        end
      end
      out
    end
  end
end
