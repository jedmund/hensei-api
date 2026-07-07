# frozen_string_literal: true

module GridDamage
  # Shapes Calculator.boost_list into the in-game "Weapon Skill Boosts" panel: display
  # lines in the game's group order (attack → HP → defense → special → overskill → AX)
  # with panel labels, in-game label-image slugs (the gbf.wiki/game texture names, EN/JA
  # variants resolved client-side), per-frame splits for the multiplicative types, and
  # preformatted display strings.
  module PanelPresenter
    module_function

    # Panel lines in game order: [key, series, label, image slug, group]. ELEMENT
    # placeholders resolve against the grid's element (Exalto / Bonus DMG badges are
    # element-specific). Multiplicative-by-series boosts list one entry per frame; keys
    # missing here still render (text label) so new boost types are never hidden.
    LINES = [
      # Attack family (red labels)
      ["atk", "normal", "Might", "might", "attack"],
      ["atk", "omega", "Ω Might", "omega-might", "attack"],
      ["atk", "ex", "EX Might", "ex-might", "attack"],
      ["ex_atk_sp", nil, "EX Might Sp.", "ex-might-sp", "attack"],
      ["stamina", "normal", "Stamina", "stamina", "attack"],
      ["stamina", "omega", "Ω Stamina", "omega-stamina", "attack"],
      ["stamina", "ex", "Stamina", "stamina", "attack"],
      ["enmity", "normal", "Enmity", "enmity", "attack"],
      ["enmity", "omega", "Ω Enmity", "omega-enmity", "attack"],
      ["enmity", "ex", "Enmity", "enmity", "attack"],
      ["e_atk", nil, "E. ATK", "e-atk", "attack"],
      ["e_atk_prog", nil, "E. ATK (Prog.)", "e-atk-prog", "attack"],
      ["critical", nil, "Critical", "critical", "attack"],
      ["da", nil, "DA Rate", "da-rate", "attack"],
      ["ta", nil, "TA Rate", "ta-rate", "attack"],
      ["optimus_exalto", nil, "ELEMENT Optimus", "ELEMENT-optimus", "attack"],
      ["omega_exalto", nil, "ELEMENT Omega", "ELEMENT-omega", "attack"],
      # Bonus DMG closes out the red group (SRiNSO panel order)
      ["bonus_elem_dmg", nil, "Bonus ELEMENT DMG", "bonus-ELEMENT-dmg", "attack"],
      ["bonus_des_dmg", nil, "Bonus Des. DMG", "bonus-des-dmg", "attack"],
      ["bonus_ca", nil, "Bonus ELEMENT C.A.", "bonus-ELEMENT-ca", "attack"],
      ["bonus_des_ca", nil, "Bonus Des. DMG C.A.", "bonus-des-dmg-ca", "attack"],
      # HP (green labels) — Heal Cap sits with HP in-game
      ["hp", nil, "HP", "hp", "hp"],
      ["heal_cap", nil, "Heal Cap", "heal-cap", "hp"],
      ["hp_cut", nil, "HP Cut", "hp-cut", "hp"],
      # Defense (blue labels) — reduction is labeled with the foe's element ("Wind Reduc."
      # on a fire grid)
      ["def", nil, "DEF", "def", "defense"],
      ["elem_reduc", nil, "FOE_ELEMENT Reduc.", "FOE_ELEMENT-reduc", "defense"],
      ["debuff_res", nil, "Debuff Res.", "debuff-res", "defense"],
      # Special (yellow labels)
      ["dmg_cap", nil, "DMG Cap", "dmg-cap", "special"],
      ["dmg_cap_sp", nil, "DMG Cap (Sp.)", "dmg-cap-sp", "special"],
      ["dmg_amp", "normal", "DMG Amp.", "dmg-amp", "special"],
      ["dmg_amp", "omega", "Ω DMG Amp.", "omega-dmg-amp", "special"],
      ["dmg_amp", "ex", "DMG Amp.", "dmg-amp", "special"],
      ["od_dmg_amp", nil, "Od DMG Amp.", "od-dmg-amp", "special"],
      ["elem_amplify", nil, "Elem. Amplify", "elem-amplify", "special"],
      ["plain_amp", nil, "DMG Amp. (Non-elem. Foe)", "plain-amp", "special"],
      ["na_dmg_cap", nil, "N.A. DMG Cap", "na-dmg-cap", "special"],
      ["na_amp", nil, "N.A. Amp.", "na-amp", "special"],
      ["na_amp_sp", nil, "N.A. Amp. (Sp.)", "na-amp-sp", "special"],
      ["skill_dmg", nil, "Skill DMG", "skill-dmg", "special"],
      ["skill_dmg_cap", nil, "Skill DMG Cap", "skill-dmg-cap", "special"],
      ["skill_cap_sp", nil, "Skill Cap (Sp.)", "skill-cap-sp", "special"],
      ["skill_amp", nil, "Skill Amp.", "skill-amp", "special"],
      ["skill_amp_sp", nil, "Skill Amp. (Sp.)", "skill-amp-sp", "special"],
      ["ca_dmg", nil, "C.A. DMG", "ca-dmg", "special"],
      ["ca_dmg_cap", nil, "C.A. DMG Cap", "ca-dmg-cap", "special"],
      ["ca_amp_sp", nil, "C.A. Amp. (Sp.)", "ca-amp-sp", "special"],
      ["sp_ca_cap", nil, "Sp. C.A. Cap", "sp-ca-cap", "special"],
      ["cb_dmg", nil, "C.B. DMG", "cb-dmg", "special"],
      ["cb_dmg_cap", nil, "C.B. DMG Cap", "cb-dmg-cap", "special"],
      ["cb_amp", nil, "C.B. Amp.", "cb-amp", "special"],
      ["fc_amp", nil, "FC Amp.", "fc-amp", "special"],
      ["crit_amp", nil, "Crit. Amp.", "crit-amp", "special"],
      ["dmg_supp", nil, "DMG Supp.", "dmg-supp", "special"],
      ["na_supp", nil, "N.A. Supp.", "na-supp", "special"],
      ["na_supp_sp", nil, "N.A. Supp. (Sp.)", "na-supp-sp", "special"],
      ["skill_dmg_supp", nil, "Skill DMG Supp.", "skill-dmg-supp", "special"],
      ["skill_supp_sp", nil, "Skill Supp. (Sp.)", "skill-supp-sp", "special"],
      ["charge_gain", nil, "Charge Gain", "charge-gain", "special"],
      ["def_ignore", nil, "DEF Ignore", "def-ignore", "special"],
      # Overskill (teal labels)
      ["crit_dmg", nil, "Crit. DMG", "crit-dmg", "overskill"],
      ["added_hit", nil, "Added Hit", "added-hit", "overskill"],
      ["dmg_cap_pen", nil, "DMG Cap Pen.", "dmg-cap-pen", "overskill"],
      ["added_hp", nil, "HP", "added-hp", "overskill"],
      # AX skills (purple labels)
      ["hp_ax", nil, "HP (AX)", "ax-hp", "ax"],
      ["atk_ax", nil, "ATK (AX)", "ax-atk", "ax"],
      ["stamina_ax", nil, "Stamina (AX)", "ax-stamina", "ax"],
      ["enmity_ax", nil, "Enmity (AX)", "ax-enmity", "ax"],
      ["def_ax", nil, "DEF (AX)", "ax-def", "ax"],
      ["da_ax", nil, "DA Rate (AX)", "ax-da-rate", "ax"],
      ["ta_ax", nil, "TA Rate (AX)", "ax-ta-rate", "ax"],
      ["ele_atk_ax", nil, "Elemental ATK (AX)", "ax-ele-atk", "ax"],
      ["ele_dmg_red_ax", nil, "Elemental Reduc. (AX)", "ax-ele-reduc", "ax"],
      ["ca_dmg_ax", nil, "C.A. DMG (AX)", "ax-ca-dmg", "ax"],
      ["ca_cap_ax", nil, "C.A. DMG Cap (AX)", "ax-ca-dmg-cap", "ax"],
      ["ca_supp_ax", nil, "C.A. Supp. (AX)", "ax-ca-supp", "ax"],
      ["skill_supp_ax", nil, "Skill DMG Supp. (AX)", "ax-skill-dmg-supp", "ax"],
      ["na_cap_ax", nil, "N.A. DMG Cap (AX)", "ax-na-dmg-cap", "ax"],
      ["healing_ax", nil, "Healing (AX)", "ax-heal", "ax"],
      ["debuff_res_ax", nil, "Debuff Res. (AX)", "ax-debuff-res", "ax"]
    ].freeze

    SUPPLEMENT_KEYS = %w[dmg_supp na_supp na_supp_sp skill_dmg_supp skill_supp_sp ca_supp
                         ca_supp_ax skill_supp_ax].freeze

    # → { enhancements: {optimus:, omega:, taboo:}, lines: [{key, series, label,
    #    label_slug, group, value, display, capped}] } for the party at the given state.
    def present(party, state: {})
      computed = Calculator.panel(party, state: state)
      agg = computed[:agg]
      contributions = active_contributions(computed[:contributions])
      element = Calculator.send(:grid_element, party)

      lines = LINES.filter_map { |spec| line_for(agg, contributions, spec, element) }
      lines += leftover_lines(agg, contributions)
      { enhancements: computed[:enhancements].transform_values { |v| v.to_f.round(2) }, lines: lines }
    end

    def line_for(agg, contributions, spec, element)
      key, series, label, slug, group = spec
      result = agg[key] or return nil
      value = series ? result.by_series&.dig(series)&.to_f : result.total.to_f
      return nil if value.nil? || value.zero?

      {
        key: key, series: series,
        label: resolve_element(label, element&.capitalize),
        label_slug: resolve_element(slug, element),
        group: group,
        value: value.round(2),
        display: display_value(key, value),
        capped: series.nil? && result.capped == true,
        sources: line_sources(result, series),
        breakdown: breakdown_for(agg, contributions, key, series)
      }
    end

    # The same activity filter the aggregator applies (main-hand gating, nil values).
    def active_contributions(contributions)
      contributions.reject { |c| c.value.nil? || (c.main_hand_only && !c.mainhand) }
    end

    OVERSKILL_FEEDS = {
      "crit_dmg" => [["Critical", "クリティカル確率", "critical", 0.5]],
      "dmg_cap_pen" => [["DMG Cap", "ダメージ上限", "dmg_cap", 0.5], ["DMG Cap (Sp.)", "ダメージ上限(特殊)", "dmg_cap_sp", 0.5]],
      "added_hit" => [["DA Rate", "DA確率", "da", 0.4], ["TA Rate", "TA確率", "ta", 0.6]],
      "added_hp" => [["HP", "HP", "hp", 0.05]]
    }.freeze

    # Per-line contribution entries: [{name:{en,ja}, icon, value, base, multiplier,
    # count}], identical skills coalesced (count > 1 ⇒ value is per copy). Overskill
    # lines synthesize their over-cap conversion instead.
    def breakdown_for(agg, contributions, key, series)
      feeds = OVERSKILL_FEEDS[key]
      return overskill_breakdown(agg, feeds) if feeds

      matching = contributions.select { |c| c.boost_type == key && (series.nil? || c.series == series) }
      matching.group_by { |c| [c.source_label, c.source_icon, c.value.to_f.round(2)] }
              .map do |(label, icon, value), group|
        first = group.first
        {
          name: label || { en: key.tr("_", " "), ja: nil },
          icon: icon,
          value: value,
          base: first.base_value&.to_f&.round(2),
          multiplier: first.multiplier&.to_f&.round(2),
          count: group.size
        }
      end
    end

    # "Critical 45.6% over the 100% cap × 0.5" style entries for the derived lines.
    def overskill_breakdown(agg, feeds)
      feeds.filter_map do |label_en, label_ja, source_key, rate|
        over = Calculator.send(:excess, agg, source_key)
        next if over.zero?

        { name: { en: "#{label_en} over cap", ja: "#{label_ja}の上限超過分" }, icon: nil,
          value: (over * rate).round(2), base: over.round(2), multiplier: rate, count: 1 }
      end
    end

    # Exalto and elemental Bonus DMG badges are element-specific in game; fall back to
    # the generic form when the grid element can't be determined.
    def resolve_element(text, element)
      return text unless text.include?("ELEMENT")

      # FOE_ELEMENT first — it contains "ELEMENT" as a substring. The foe's element is
      # what the grid's element is strong against (fire grid → "Wind Reduc.").
      if text.include?("FOE_ELEMENT")
        foe = element && Calculator::ADVANTAGED_FOE[element.downcase]
        return text.gsub("FOE_ELEMENT-reduc", "elem-reduc").gsub(/FOE_ELEMENT\s*/, "Elem. ").strip if foe.nil?

        foe = foe.capitalize if element.match?(/\A[A-Z]/)
        return text.gsub("FOE_ELEMENT", foe)
      end
      return text.gsub("ELEMENT", element) if element

      text.gsub("bonus-ELEMENT-dmg", "bonus-elem-dmg").gsub(/\s*ELEMENT\s*/, " ").strip
    end

    # Grid weapon ids contributing to this line (per-frame for series-split lines).
    def line_sources(result, series)
      map = result.try(:source_map) || {}
      ids = series ? Array(map[series]) : map.values.flatten
      ids.uniq
    end

    # Supplements are flat counts (+100,000); everything else is a percent.
    def display_value(key, value)
      return format("%+d", value).gsub(/(\d)(?=(\d{3})+\z)/, '\1,') if SUPPLEMENT_KEYS.include?(key)

      rounded = value.round(2)
      rounded = rounded.to_i if rounded == rounded.to_i
      "#{rounded}%"
    end

    # Boost types not in the ordered map still render, so nothing is silently hidden.
    def leftover_lines(agg, contributions)
      known = LINES.to_set(&:first)
      agg.except(*known).filter_map do |key, result|
        value = result.total.to_f
        next if value.zero?

        { key: key, series: nil, label: key.tr("_", " "), label_slug: nil, group: "other",
          value: value.round(2), display: display_value(key, value),
          capped: result.capped == true, sources: line_sources(result, nil),
          breakdown: breakdown_for(agg, contributions, key, nil) }
      end
    end
  end
end
