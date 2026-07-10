# frozen_string_literal: true

module GridDamage
  # Phase 5: evaluates the grid's weapon_skill_effects (the conditional/special track) at a
  # battle state into Aggregator::Contributions, to merge with the Phase 1/2 data
  # contributions. Covers static/flat, conditional_flat, per_grid_count,
  # supplemental_cap, bonus_dmg, and HP-scaled kinds. ATK-type effects carry their
  # series so the frame math folds them into Normal/Omega/EX.
  module Effects
    CAP_FORMULA_PATTERN = %r{
      \A
      (?<slope>\d+(?:\.\d+)?)
      \*
      (?<ratio>\(\(maxhp-curhp\)/maxhp\)|\(curhp/maxhp\))
      \+
      (?<base>\d+(?:\.\d+)?)
      \z
    }x.freeze

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
      # Persistence supplements scale with current HP: value x (1 + 2*hp/100)/3
      # (QJ9736: 30000 -> 25000/20000/15000/10200, exact at all five anchors)
      when "persistence_supp"
        effect.value.to_f * (1 + (2 * state.fetch(:hp_percent, 100).to_f / 100)) / 3.0
      # "Up to N%" linear-in-HP boosts with the stamina-style sub-25 cutoff
      # (Rightway Pathfinder: 120 x hp/100 -> 120/90/60/30, gone below 25)
      when "hp_linear_cutoff"
        hp = state.fetch(:hp_percent, 100).to_f
        hp < 25 ? nil : effect.value.to_f * hp / 100.0
      when "hp_current_linear"
        hp_linear_value(effect, state: state, missing: false)
      when "hp_missing_linear"
        hp_linear_value(effect, state: state, missing: true)
      when "supplemental_cap"
        supplemental_cap(effect, state: state)
      when "ally_max_hp_scaled"
        ally_max_hp_scaled(effect, state: state)
      when "ally_hp_scaled", "current_hp_scaled" # Legacy placeholders; avoid new rows.
        effect.value&.to_f
      when "specialty_scaled"
        specialty_value(effect, composition: composition, state: state)
      when "documentation"
        nil
      end
    end

    def hp_linear_value(effect, state:, missing:)
      floor = effect.value&.to_f
      ceiling = effect.total_cap&.to_f
      return nil if floor.nil? || ceiling.nil?

      # The in-game calculator's "1%" anchor behaves as the 1-HP endpoint for these
      # linear MA skills: Exertion shows 5%, Surge shows 35%.
      hp = state.fetch(:hp_percent, 100).to_f
      current_ratio = hp <= 1 ? 0.0 : (hp / 100.0).clamp(0.0, 1.0)
      ratio = missing ? 1.0 - current_ratio : current_ratio
      floor + ((ceiling - floor) * ratio)
    end

    def ally_max_hp_scaled(effect, state:)
      max_hp = state[:ally_max_hp]&.to_f
      coefficient = effect.value&.to_f
      return nil if max_hp.nil? || max_hp <= 0 || coefficient.nil?

      value = max_hp * coefficient / 100.0
      cap = effect.per_copy_cap&.to_f
      cap ? [value, cap].min : value
    end

    def supplemental_cap(effect, state:)
      return cap_formula_value(effect.cap_formula, state: state) if effect.cap_formula.present?

      effect.per_copy_cap&.to_f # assume foe HP high enough to reach the per-copy cap (panel shows the cap)
    end

    def cap_formula_value(formula, state:)
      match = formula.to_s.delete(" ").match(CAP_FORMULA_PATTERN)
      return nil unless match

      hp = state.fetch(:hp_percent, 100).to_f
      current_ratio = hp <= 1 ? 0.0 : (hp / 100.0).clamp(0.0, 1.0)
      ratio = match[:ratio].include?("maxhp-curhp") ? 1.0 - current_ratio : current_ratio
      match[:base].to_f + (match[:slope].to_f * ratio)
    end

    # Per-specialty skills (e.g. Cloud of Howling Twilight) grant a value by the viewer's weapon
    # specialty. The panel reflects the MC's specialties (either job proficiency counts);
    # allies of that specialty get the larger boost, everyone else the "other" row.
    # An "arcarum" flag in the condition venue-gates the row (Sephirath skills apply
    # only in Arcarum: The World Beyond / Replicard Sandbox).
    def specialty_value(effect, composition:, state: {})
      return nil if effect.condition["arcarum"] && !state[:arcarum]

      table = effect.condition["specialties"] || effect.condition[:specialties] or return nil
      specs = Array(composition && (composition[:mc_specialties] || composition[:mc_specialty]))
      matched = specs.filter_map { |s| table[s] }.max
      (matched || table["other"])&.to_f
    end

    def per_grid_count(effect, weapon:, composition:)
      base = effect.value&.to_f
      count = grid_count(effect.count_basis, effect: effect, weapon: weapon, composition: composition)
      return nil if base.nil? || count.nil?

      count = [count, effect.count_cap.to_i].min if effect.count_cap
      total = base * count
      # a non-shared per_grid_count caps its own total (per_copy_cap here acts as that cap);
      # shared groups are capped by the aggregator instead.
      individual = effect.per_copy_cap&.to_f
      total = [total, individual].min if individual && effect.shared_cap_group.blank?
      total
    end

    def grid_count(basis, weapon:, composition:, effect: nil)
      case basis
      when "weapon_type"  then composition.dig(:weapon_type_counts, weapon.proficiency).to_i
      when "weapon_group" then composition[:weapon_group_count].to_i
      when "weapon_series"
        composition.dig(:weapon_series_counts, weapon.weapon_series&.slug).to_i
      when "epic", "militis", "grand"
        composition.dig(:weapon_series_counts, basis).to_i
      when "omega_skill"  then composition[:omega_skill_count].to_i
        # characters (incl. MC) whose race is in the effect's condition list — bahamut
        # weapons' Vita family counts crew, not weapons (HDbPnu: 2% x 5 matching)
      when "crew_races"
        races = Array(effect.condition&.dig("races")).map(&:to_i)
        composition.fetch(:character_races, []).count { |r| races.include?(r.to_i) }
      end
    end

    # Cap-group key: an explicit shared group, else a per-modifier group when the effect
    # has its own total_cap (so the aggregator caps that modifier's summed contributions).
    def cap_group(effect)
      effect.shared_cap_group.presence || (effect.total_cap ? "#{effect.modifier}|#{effect.boost_type}" : nil)
    end
  end
end
