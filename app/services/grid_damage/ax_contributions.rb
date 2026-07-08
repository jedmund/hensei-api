# frozen_string_literal: true

module GridDamage
  # AX (EX) skill contributions: per-copy augments on gacha weapons, stored on the grid
  # weapon (ax_modifier1/2 + strengths). The panel shows them as their own purple lines,
  # SEPARATE from the weapon-skill lines (mcwZet: Sunblade AX "HP +8 / Stamina +3" shows
  # as purple HP 8% / Stamina 5%), so they aggregate under "<stat>_ax" keys and are never
  # summon-amplified.
  module AxContributions
    module_function

    # Stamina/Enmity AX strengths are levels, not percents; the panel converts them.
    # Only the panel-proven point is encoded (strength 3 → 5% at full HP); unknown
    # strengths fall back to the raw value until another golden panel pins them.
    # gbf.wiki/AX_Skills modifier-value tables: Stamina/Enmity AX are LEVELS whose
    # panel value depends on current HP (anchors at 100/75/50/25/0; linear between).
    # OlFQ2a validates the whole stamina table: two augments (lv3+lv2) show
    # 9/9/8/6/4 across the HP sweep.
    STAMINA_AX = {
      1 => { 100 => 3.0, 75 => 2.5, 50 => 2.0, 25 => 1.5, 0 => 1.0 },
      2 => { 100 => 4.0, 75 => 4.0, 50 => 4.0, 25 => 3.0, 0 => 2.0 },
      3 => { 100 => 5.0, 75 => 5.0, 50 => 4.0, 25 => 3.0, 0 => 2.0 }
    }.freeze
    ENMITY_AX = {
      1 => { 100 => 1.0, 75 => 2.0, 50 => 2.26, 25 => 3.63, 0 => 5.0 },
      2 => { 100 => 1.0, 75 => 2.0, 50 => 2.33, 25 => 4.17, 0 => 6.0 },
      3 => { 100 => 1.0, 75 => 3.0, 50 => 3.37, 25 => 5.44, 0 => 7.0 }
    }.freeze
    HP_ANCHORS = [100, 75, 50, 25, 0].freeze
    # Supplemental AX skills are levels 1-5 with fixed damage values.
    SUPP_DISPLAY = {
      "ca_supp" => { 1 => 10_000.0, 2 => 15_000.0, 3 => 20_000.0, 4 => 25_000.0, 5 => 30_000.0 },
      "skill_supp" => { 1 => 1000.0, 2 => 1500.0, 3 => 2000.0, 4 => 2500.0, 5 => 3000.0 }
    }.freeze

    def for_party(party, state: {})
      hp = state.fetch(:hp_percent, 100).to_f
      mods = WeaponStatModifier.where(category: "ax").index_by(&:id)
      party.weapons.flat_map do |gw|
        [[gw.ax_modifier1_id, gw.ax_strength1], [gw.ax_modifier2_id, gw.ax_strength2]].filter_map do |mod_id, strength|
          mod = mods[mod_id] or next
          value = display_value(mod, strength.to_f, hp)
          next if value.zero?

          shown = strength.to_f
          shown = shown.to_i if shown == shown.round
          # a multiattack augment lands on BOTH rate lines at full strength
          # (HDbPnu: one ax_multiattack 2.5 shows DA 2.5 and TA 2.5)
          keys = mod.stat == "multiattack" ? %w[da_ax ta_ax] : ["#{mod.stat}_ax"]
          keys.map do |key|
            Aggregator::Contribution.new(
              boost_type: key, series: nil, value: value,
              main_hand_only: false, mainhand: gw.mainhand, amplifiable: false,
              source_ids: [gw.id],
              source_label: { en: "AX: #{mod.name_en} +#{shown}", ja: "AX: #{mod.name_jp} +#{shown}" }
            )
          end
        end.flatten
      end
    end

    # anchor lookup with linear interpolation between the wiki's HP breakpoints
    def hp_scaled(anchors, hp_pct)
      return anchors[hp_pct.to_i] if anchors.key?(hp_pct.to_i)

      upper = HP_ANCHORS.reverse.find { |a| a >= hp_pct } || 100
      lower = HP_ANCHORS.find { |a| a <= hp_pct } || 0
      return anchors[upper] if upper == lower

      t = (hp_pct - lower) / (upper - lower).to_f
      (anchors[lower] + ((anchors[upper] - anchors[lower]) * t)).round(2)
    end

    def display_value(mod, strength, hp_pct)
      if %w[stamina enmity].include?(mod.stat)
        table = mod.stat == "stamina" ? STAMINA_AX : ENMITY_AX
        return hp_scaled(table[strength.to_i.clamp(1, 3)], hp_pct)
      end
      return SUPP_DISPLAY.fetch(mod.stat).fetch(strength.to_i, strength) if SUPP_DISPLAY.key?(mod.stat)

      strength
    end
  end
end
