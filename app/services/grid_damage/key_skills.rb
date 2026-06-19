# frozen_string_literal: true

module GridDamage
  # Resolves a grid weapon's KEY-granted skills: maps each equipped weapon_key to the
  # weapon_skill_effects tagged with that key's slug, evaluates them at the battle state
  # (reusing GridDamage::Effects), and emits contributions with the correct frame.
  # Frame rules: `weapon_identity` (Dark Opus — Renunciation Omega / Repudiation Normal),
  # `teluma` (Draconic Six Dragons — Omega/Optimus Teluma), `none` (use the effect's own
  # series; EX or non-frame).
  module KeySkills
    module_function

    def contributions(party, state: {}, composition: nil)
      composition ||= GridComposition.for_party(party)
      by_slug = effects_by_slug
      return [] if by_slug.empty?

      out = []
      party.weapons.includes(:weapon).each do |gw|
        w = gw.weapon
        next unless w

        equipped_key_slugs(gw).each do |slug|
          Array(by_slug[slug]).each do |e|
            value = Effects.value_for(e, weapon: w, state: state, composition: composition)
            next if value.nil? || value.zero?

            out << Aggregator::Contribution.new(
              boost_type: e.boost_type, series: frame_for(e, w, gw), value: value,
              mainhand: gw.mainhand, shared_cap_group: e.shared_cap_group, cap: e.total_cap&.to_f
            )
          end
        end
      end
      out
    end

    def effects_by_slug
      WeaponSkillEffect.where.not(key_slug: nil).group_by(&:key_slug)
    end

    def equipped_key_slugs(grid_weapon)
      ids = [grid_weapon.weapon_key1_id, grid_weapon.weapon_key2_id,
             grid_weapon.weapon_key3_id, grid_weapon.weapon_key4_id].compact
      return [] if ids.empty?

      WeaponKey.where(id: ids).pluck(:slug)
    end

    def frame_for(effect, weapon, grid_weapon)
      case effect.frame_rule
      when "weapon_identity"
        weapon.name_en.to_s.include?("Renunciation") ? "omega" : "normal"
      when "teluma"
        teluma_frame(grid_weapon)
      else
        effect.series # "none": EX ATK keeps its series; non-frame boost_types ignore it
      end
    end

    # Draconic Six Dragons' Radiance: Omega Teluma → omega, Optimus Teluma → normal.
    def teluma_frame(grid_weapon)
      slugs = equipped_key_slugs(grid_weapon)
      return "omega" if slugs.include?("teluma-omega")
      return "normal" if slugs.include?("teluma-optimus")

      "normal"
    end

    private_class_method :effects_by_slug, :equipped_key_slugs, :frame_for, :teluma_frame
  end
end
