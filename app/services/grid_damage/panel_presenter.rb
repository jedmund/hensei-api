# frozen_string_literal: true

module GridDamage
  # Shapes Calculator.boost_list into the in-game "Weapon Skill Boosts" panel: ordered
  # display lines with panel labels, per-frame splits for the multiplicative types, and
  # preformatted display strings (the panel floors integers and suffixes %; supplements
  # render as +N with thousands separators).
  module PanelPresenter
    module_function

    # Panel order and labels. Multiplicative-by-series boosts list one entry per frame;
    # keys missing here still render (humanized) so new boost types are never hidden.
    LINES = [
      ["optimus_exalto", nil, "Optimus (Exalto)"],
      ["omega_exalto", nil, "Omega (Exalto)"],
      %w[atk normal Might],
      ["atk", "omega", "Ω Might"],
      ["atk", "ex", "EX Might"],
      ["ex_atk_sp", nil, "EX Might Sp."],
      ["stamina", "normal", "Stamina"],
      ["stamina", "omega", "Ω Stamina"],
      ["stamina", "ex", "Stamina"],
      ["enmity", nil, "Enmity"],
      ["e_atk", nil, "E. ATK"],
      ["e_atk_prog", nil, "Progression"],
      ["critical", nil, "Critical"],
      ["crit_amp", nil, "Crit. Amp."],
      ["da", nil, "DA Rate"],
      ["ta", nil, "TA Rate"],
      ["hp", nil, "HP"],
      ["hp_cut", nil, "HP Cut"],
      ["def", nil, "DEF"],
      ["def_ignore", nil, "DEF Ignore"],
      ["elem_reduc", nil, "Elem. Reduc."],
      ["dmg_cap", nil, "DMG Cap"],
      ["dmg_cap_pen", nil, "DMG Cap Pen."],
      ["dmg_amp", "normal", "DMG Amp."],
      ["dmg_amp", "omega", "Ω DMG Amp."],
      ["dmg_amp", "ex", "DMG Amp."],
      ["elem_amplify", nil, "Elem. Amplify"],
      ["na_dmg_cap", nil, "N.A. DMG Cap"],
      ["na_amp", nil, "N.A. Amp."],
      ["na_amp_sp", nil, "N.A. Amp. (Sp.)"],
      ["skill_dmg", nil, "Skill DMG"],
      ["skill_dmg_cap", nil, "Skill DMG Cap"],
      ["skill_cap_sp", nil, "Skill Cap (Sp.)"],
      ["skill_amp", nil, "Skill Amp."],
      ["skill_amp_sp", nil, "Skill Amp. (Sp.)"],
      ["ca_dmg", nil, "C.A. DMG"],
      ["ca_dmg_cap", nil, "C.A. DMG Cap"],
      ["sp_ca_cap", nil, "C.A. Cap (Sp.)"],
      ["cb_dmg_cap", nil, "C.B. DMG Cap"],
      ["charge_gain", nil, "Charge Gain"],
      ["dmg_supp", nil, "DMG Supp."],
      ["na_supp", nil, "N.A. Supp."],
      ["na_supp_sp", nil, "N.A. Supp. (Sp.)"],
      ["skill_dmg_supp", nil, "Skill DMG Supp."],
      ["skill_supp_sp", nil, "Skill Supp. (Sp.)"],
      ["bonus_elem_dmg", nil, "Bonus Elem. DMG"],
      ["bonus_des_dmg", nil, "Bonus Des. DMG"],
      ["bonus_des_ca", nil, "Bonus Des. DMG C.A."],
      ["heal_cap", nil, "Heal Cap"],
      ["hp_ax", nil, "HP (AX)"],
      ["stamina_ax", nil, "Stamina (AX)"]
    ].freeze

    SUPPLEMENT_KEYS = %w[dmg_supp na_supp na_supp_sp skill_dmg_supp skill_supp_sp ca_supp].freeze

    # → { enhancements: {optimus:, omega:, taboo:}, lines: [{key, series, label, value,
    #    display, capped}] } for the party at the given battle state.
    def present(party, state: {})
      agg = Calculator.boost_list(party, state: state)
      enh = Calculator.send(:enhancements, party, agg)

      lines = LINES.filter_map { |key, series, label| line_for(agg, key, series, label) }
      lines += leftover_lines(agg)
      { enhancements: enh.transform_values { |v| v.to_f.round(2) }, lines: lines }
    end

    def line_for(agg, key, series, label)
      result = agg[key] or return nil
      value = series ? result.by_series&.dig(series)&.to_f : result.total.to_f
      return nil if value.nil? || value.zero?

      {
        key: key, series: series, label: label,
        value: value.round(2),
        display: display_value(key, value),
        capped: series.nil? && result.capped == true
      }
    end

    # Supplements are flat counts (+100,000); everything else is a percent.
    def display_value(key, value)
      return format("%+d", value).gsub(/(\d)(?=(\d{3})+\z)/, '\1,') if SUPPLEMENT_KEYS.include?(key)

      rounded = value.round(2)
      rounded = rounded.to_i if rounded == rounded.to_i
      "#{rounded}%"
    end

    # Boost types not in the ordered map still render, so nothing is silently hidden.
    def leftover_lines(agg)
      known = LINES.to_set(&:first)
      agg.except(*known).filter_map do |key, result|
        value = result.total.to_f
        next if value.zero?

        { key: key, series: nil, label: key.tr("_", " "), value: value.round(2),
          display: display_value(key, value), capped: result.capped == true }
      end
    end
  end
end
