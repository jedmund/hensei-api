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

        skill_level = skill_level_for(w, gw)
        amplifiable = !NON_SUMMON_BOOSTED_SERIES.include?(w.weapon_series&.slug)
        active_versions(w, gw).each do |v|
          # The frame is the weapon's series (normal/omega/ex/…); for aura-word-less special
          # weapons (Dark Opus, Draconic) it comes from the weapon's identity. Never use the
          # data row's shared `normal_omega` designation as a frame.
          frame = FrameResolver.frame_for(w, v)
          v.weapon_skill_data.each do |d|
            value = Scaling.value(d, skill_level: skill_level, hp_percent: hp, turn: turn)
            out << Aggregator::Contribution.new(
              boost_type: d.boost_type, series: frame,
              value: value, main_hand_only: v.main_hand_only, mainhand: gw.mainhand,
              amplifiable: amplifiable, source_ids: [gw.id],
              source_label: { en: v.skill&.name_en, ja: v.skill&.name_jp },
              source_icon: v.icon_stem
            )
          end
        end
      end
      out
    end

    # An upgraded skill imported as a SEPARATE slot replaces its base in-game — both
    # being active would double-count. Upgrades come as a Roman suffix ("Sephirath
    # Brogue II") or a "True" prefix (Xeno: "True Solaris's Supremacy" supersedes
    # "Solaris's Supremacy"). Group the slots' active versions by name stem and keep
    # the highest variant.
    ROMAN_SUFFIX = /\s+(II|III|IV)\z/
    ROMAN_RANK = { nil => 1, "II" => 2, "III" => 3, "IV" => 4 }.freeze
    TRUE_PREFIX = /\ATrue\s+/

    def active_versions(weapon, grid_weapon)
      active = weapon.weapon_skills.filter_map do |ws|
        ws.active_version(uncap_level: grid_weapon.uncap_level.to_i,
                          transcendence_step: grid_weapon.transcendence_step.to_i)
      end
      active.group_by { |v| skill_stem(v) }.flat_map do |stem, group|
        next group if group.size == 1 || stem.blank?

        [group.max_by { |v| variant_rank(skill_name(v)) }]
      end
    end

    def skill_stem(version)
      skill_name(version).sub(TRUE_PREFIX, "").sub(ROMAN_SUFFIX, "")
    end

    def variant_rank(name)
      rank = ROMAN_RANK[name[ROMAN_SUFFIX, 1]] || 1
      name.match?(TRUE_PREFIX) ? rank + 10 : rank
    end

    def skill_name(version)
      version.skill&.name_en.to_s
    end

    # The skill level of THIS grid copy, assuming it's leveled to its uncap's cap (the
    # calculator convention): SL10 below MLB, SL15 at 3–4★, SL20 at ULB. Transcendence
    # stages 1–4 don't raise it; the FINAL stage (5) jumps +5 → SL25. Clamped to the
    # weapon's own maximum, so an FLB copy of an ULB-capable weapon reads SL15, not SL20.
    def skill_level_for(weapon, grid_weapon)
      # an explicit skill level wins — players don't always feed fodder to the max
      explicit = grid_weapon.try(:skill_level)
      return explicit.to_i if explicit.present?

      uncap = grid_weapon.uncap_level.to_i
      transcended = grid_weapon.transcendence_step.to_i >= 5
      cap = if uncap >= 5 then 20
            elsif uncap >= 3 then 15
            else
              10
            end
      cap += 5 if transcended
      [cap, (weapon.max_skill_level || 15) + (transcended ? 5 : 0)].min
    end
  end
end
