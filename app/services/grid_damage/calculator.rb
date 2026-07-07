# frozen_string_literal: true

module GridDamage
  # Orchestrator: merges weapon-skill DATA (Phase 1/2), conditional EFFECTS (Phase 5), and
  # KEY-granted skills (Phase 6) into the in-game "Weapon Skill Boosts" list. Runs a second
  # pass when any frame enhancement reaches ≥280%, so self-referential `boost_level`
  # effects (Opus pendulums, Destroyer anklets) can activate.
  module Calculator
    module_function

    ELEMENT_WORD = { 1 => "wind", 2 => "fire", 3 => "water", 4 => "earth", 5 => "dark", 6 => "light" }.freeze
    # What each grid element is strong against — the default foe, and the element named
    # by the panel's reduction line ("Wind Reduc." on a fire grid).
    ADVANTAGED_FOE = { "fire" => "wind", "water" => "fire", "earth" => "water",
                       "wind" => "earth", "light" => "dark", "dark" => "light" }.freeze
    BOOST_LEVEL_THRESHOLD = 280.0
    # Confirmed weapon-skill display caps (gbf.wiki/Weapon_Skills#Weapon_Skill_Caps). The panel
    # shows a boost orange once it reaches its cap. A "100% hit to multiattack" penalty (−100 DA)
    # can still push the post-cap DA negative.
    RATE_CAPS = { "da" => 75.0, "ta" => 75.0, "critical" => 100.0,
                  "dmg_cap" => 20.0, "dmg_cap_sp" => 20.0, "na_dmg_cap" => 20.0,
                  "ca_dmg_cap" => 100.0, "skill_dmg_cap" => 100.0, "heal_cap" => 100.0,
                  "ex_atk_sp" => 80.0, "crit_amp" => 20.0,
                  # SRiNSO/R1ckYi/HoEE8b panels (2026-07-06): orange at the values below.
                  "elem_reduc" => 30.0, "na_amp" => 30.0, "na_amp_sp" => 20.0,
                  "bonus_elem_dmg" => 50.0,
                  "skill_cap_sp" => 60.0, "skill_amp_sp" => 20.0,
                  "dmg_supp" => 100_000.0, "na_supp" => 100_000.0,
                  "skill_dmg_supp" => 200_000.0 }.freeze

    # Boosts that the summon-aura/Exalto "Weapon Skill Enhancement" amplifies (per frame):
    # the offensive ATK-family, the rate boosts, the amplify-family, elemental Bonus DMG
    # (5JPIJg: Deathstrike 4.5×2 × 5.2 = 46.8 = the panel's Bonus Water DMG, exactly),
    # DEF Ignore (dAV5ds: Impalement 2×2 × 2.5 = 10, exactly), and Heal Cap (SRiNSO:
    # Precocity 15 × 5.3 = 79.5, exactly). DMG caps, supplementals, and DEF are NOT amplified.
    AMPLIFIED_BOOSTS = %w[atk hp stamina enmity e_atk_prog critical da ta def_ignore
                          dmg_amp crit_amp elem_amplify od_dmg_amp bonus_elem_dmg heal_cap].freeze

    # → { boost_type => Aggregator::Result } for the party at the given battle state.
    def boost_list(party, state: {})
      panel(party, state: state)[:agg]
    end

    # Full panel computation: the aggregate PLUS the final (amplified) contribution list
    # that produced it — the per-line breakdown the UI explains the math with.
    def panel(party, state: {})
      composition = GridComposition.for_party(party)
      agg = aggregate_pass(party, state, composition) # pass 1 (raw) — to read the Exalto totals

      enh = enhancements(party, agg)
      # Pass 2: amplify each contribution by its frame's enhancement before aggregating, and
      # feed the enhancements in so boost_level (≥280) effects can fire too.
      contributions = collect_contributions(party, state.merge(enhancements: enh), composition)
      contributions = amplify_contributions(contributions, enh)
      agg = Aggregator.aggregate(contributions)
      apply_rate_caps(agg)
      add_overskills(agg)
      { agg: agg, contributions: contributions, enhancements: enh }
    end

    # Overskills (gbf.wiki/Overskills): over-cap excess converts into derived lines.
    # Panel-exact on all goldens — 9JtcHY: Critical raw 145.6 → Crit. DMG 22.8; DMG Cap
    # raw 31 → Pen. 5.5; dAV5ds raw 24 → 2; 5JPIJg raw 42 → 11.
    OVERSKILL_CAPS = { "crit_dmg" => 100.0, "dmg_cap_pen" => 20.0, "added_hit" => 100.0 }.freeze

    def add_overskills(agg)
      crit = excess(agg, "critical") * 0.5
      cap_excess = excess(agg, "dmg_cap") + excess(agg, "dmg_cap_sp")
      pen = cap_excess >= 2 ? cap_excess * 0.5 : 0.0 # 2% minimum excess to activate
      hit = (excess(agg, "da") * 0.4) + (excess(agg, "ta") * 0.6)

      overskill_sources = { "crit_dmg" => %w[critical], "dmg_cap_pen" => %w[dmg_cap dmg_cap_sp],
                            "added_hit" => %w[da ta] }
      { "crit_dmg" => crit, "dmg_cap_pen" => pen, "added_hit" => hit }.each do |key, value|
        next unless value.positive?

        cap = OVERSKILL_CAPS.fetch(key)
        sources = overskill_sources[key].flat_map { |k| (agg[k]&.source_map || {}).values.flatten }.uniq
        agg[key] = Aggregator::Result.new(boost_type: key, total: [value, cap].min,
                                          raw: value, capped: value >= cap,
                                          source_map: { nil => sources })
      end
      agg
    end

    def excess(agg, boost_type)
      r = agg[boost_type]
      return 0.0 unless r&.capped && r.raw

      [r.raw.to_f - r.total.to_f, 0.0].max
    end

    # Clamp totals to their in-game cap (upper bound only — DA may be negative). The
    # panel shows a value orange AT its cap too, so exactly-at-cap flags as capped.
    def apply_rate_caps(agg)
      RATE_CAPS.each do |boost_type, cap|
        r = agg[boost_type]
        next unless r && r.total >= cap

        # keep the aggregator's pre-cap raw (Overskills convert the over-cap excess)
        r.raw = [r.raw.to_f, r.total.to_f].max
        r.total = cap
        r.capped = true
      end
      agg
    end

    # Per-frame enhancement totals (summon + character auras + Exalto) — what `boost_level`
    # conditions compare against.
    def enhancements(party, agg)
      element = grid_element(party)
      auras = Auras.for_party(party, element: element)
      {
        optimus: auras[:optimus] + [agg["optimus_exalto"]&.total.to_f || 0.0, 90].min,
        omega: auras[:omega] + [agg["omega_exalto"]&.total.to_f || 0.0, 100].min,
        # Odious summons' base aura. The exorcism-level scaling on top (aura base → its
        # [Max] via equipped Odious weapons' exorcism lvls) still needs in-game ground truth.
        taboo: auras[:taboo]
      }
    end

    def aggregate_pass(party, state, composition, amplify_enh: nil)
      contributions = collect_contributions(party, state, composition)
      contributions = amplify_contributions(contributions, amplify_enh) if amplify_enh
      Aggregator.aggregate(contributions)
    end

    def collect_contributions(party, state, composition)
      WeaponContributions.for_party(party, state: state) +
        Effects.contributions(party, state: state, composition: composition) +
        KeySkills.contributions(party, state: state, composition: composition) +
        AwakeningContributions.for_party(party) +
        AxContributions.for_party(party)
    end

    # Multiply each amplifiable contribution by its frame's enhancement (Optimus/Omega aura +
    # Exalto; EX/odious-without-Taboo unaffected) BEFORE aggregating, so per-series sums (ATK)
    # and additive sums (crit/DA/TA) are both correctly amplified.
    def amplify_contributions(contributions, enh)
      factor = { "normal" => 1 + (enh[:optimus].to_f / 100), "omega" => 1 + (enh[:omega].to_f / 100),
                 "ex" => 1.0, "odious" => 1 + (enh[:taboo].to_f / 100) }
      contributions.map do |c|
        next c if c.amplifiable == false # flat sources (weapon awakenings) aren't enhanced
        next c unless c.value && AMPLIFIED_BOOSTS.include?(c.boost_type)

        f = factor[c.series] || 1.0
        next c if (f - 1.0).abs < Float::EPSILON

        c.class.new(**c.to_h, value: c.value * f, base_value: c.value, multiplier: f)
      end
    end

    def grid_element(party)
      id = party.weapons.filter_map { |gw| gw.element || gw.weapon&.element }
                .group_by(&:itself).max_by { |_, v| v.size }&.first
      ELEMENT_WORD[id]
    end

    private_class_method :enhancements, :aggregate_pass, :collect_contributions, :grid_element,
                         :amplify_contributions
  end
end
