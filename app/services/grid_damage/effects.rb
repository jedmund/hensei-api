# frozen_string_literal: true

module GridDamage
  # Phase 5: evaluates the grid's weapon_skill_effects (the conditional/special track) at a
  # battle state into Aggregator::Contributions, to merge with the Phase 1/2 data
  # contributions. Covers static/flat, conditional_flat, per_grid_count,
  # foe_hp_supplemental, bonus_dmg, and HP-scaled kinds. ATK-type effects carry their
  # series so the frame math folds them into Normal/Omega/EX.
  module Effects
    module_function

    def contributions(party, state: {}, composition: nil)
      composition ||= GridComposition.for_party(party)
      out = []
      party.weapons.includes(weapon: { weapon_skills: :weapon_skill_versions }).each do |gw|
        w = gw.weapon
        next unless w

        # Non-summon-boosted series (Bahamut/Celestial) land on the panel flat, like EX.
        amplifiable = !WeaponContributions::NON_SUMMON_BOOSTED_SERIES.include?(w.weapon_series&.slug)
        WeaponContributions.active_versions(w, gw).each do |v|
          # The wiki Multiplier (captured at expansion) is the authoritative frame for the whole
          # skill; otherwise fall back to the effect's heuristic series.
          frame = v.try(:multiplier_frame).presence
          v.weapon_skill_effects.each do |e|
            value = value_for(e, weapon: w, state: state, composition: composition, grid_weapon: gw)
            next if value.nil? || value.zero?

            out << Aggregator::Contribution.new(
              boost_type: e.boost_type, series: frame || e.series, value: value,
              main_hand_only: v.main_hand_only, mainhand: gw.mainhand,
              shared_cap_group: cap_group(e), cap: e.total_cap&.to_f, amplifiable: amplifiable,
              source_ids: [gw.id],
              source_label: { en: v.skill&.name_en, ja: v.skill&.name_jp },
              source_icon: v.icon_stem
            )
          end
        end
      end
      out
    end

    # The per-copy value of one effect at the state (nil = doesn't apply / unmodeled).
    def value_for(effect, weapon:, state:, composition:, grid_weapon: nil)
      case effect.scaling_kind
      when "static", "flat"
        effect.value&.to_f
      when "conditional_flat", "bonus_dmg"
        met = Conditions.met?(effect.condition, state: state, composition: composition,
                              weapon: weapon, grid_weapon: grid_weapon)
        met ? effect.value&.to_f : nil
      when "per_grid_count"
        per_grid_count(effect, weapon: weapon, composition: composition)
      when "foe_hp_supplemental"
        effect.per_copy_cap&.to_f # assume foe HP high enough to reach the per-copy cap (panel shows the cap)
      when "ally_hp_scaled", "current_hp_scaled"
        effect.value&.to_f # TODO: HP curve (small set) — placeholder
      when "specialty_scaled"
        specialty_value(effect, composition: composition)
      end
    end

    # Per-specialty skills (e.g. Cloud of Howling Twilight) grant a value by the viewer's weapon
    # specialty. The panel reflects the MC's specialties (either job proficiency counts);
    # allies of that specialty get the larger boost, everyone else the "other" row.
    def specialty_value(effect, composition:)
      table = effect.condition["specialties"] || effect.condition[:specialties] or return nil
      specs = Array(composition && (composition[:mc_specialties] || composition[:mc_specialty]))
      matched = specs.filter_map { |s| table[s] }.max
      (matched || table["other"])&.to_f
    end

    def per_grid_count(effect, weapon:, composition:)
      base = effect.value&.to_f
      count = grid_count(effect.count_basis, weapon: weapon, composition: composition)
      return nil if base.nil? || count.nil?

      count = [count, effect.count_cap.to_i].min if effect.count_cap
      total = base * count
      # a non-shared per_grid_count caps its own total (per_copy_cap here acts as that cap);
      # shared groups are capped by the aggregator instead.
      individual = effect.per_copy_cap&.to_f
      total = [total, individual].min if individual && effect.shared_cap_group.blank?
      total
    end

    def grid_count(basis, weapon:, composition:)
      case basis
      when "weapon_type"  then composition.dig(:weapon_type_counts, weapon.proficiency).to_i
      when "weapon_group" then composition[:weapon_group_count].to_i
      when "omega_skill"  then composition[:omega_skill_count].to_i
        # "epic"/"militis" need weapon-group tags we don't store — documented gap.
      end
    end

    # Cap-group key: an explicit shared group, else a per-modifier group when the effect
    # has its own total_cap (so the aggregator caps that modifier's summed contributions).
    def cap_group(effect)
      effect.shared_cap_group.presence || (effect.total_cap ? "#{effect.modifier}|#{effect.boost_type}" : nil)
    end
  end
end
