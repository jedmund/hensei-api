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
    STAMINA_DISPLAY = { 3 => 5.0 }.freeze
    # Supplemental AX augments display flat damage per strength point (XJZZmv:
    # Skill DMG Supp. strength 3 shows +2,000 — the only proven point).
    SUPP_DISPLAY = { "skill_supp" => { 3 => 2000.0 }, "ca_supp" => { 5 => 30_000.0 } }.freeze

    def for_party(party)
      mods = WeaponStatModifier.where(category: "ax").index_by(&:id)
      party.weapons.flat_map do |gw|
        [[gw.ax_modifier1_id, gw.ax_strength1], [gw.ax_modifier2_id, gw.ax_strength2]].filter_map do |mod_id, strength|
          mod = mods[mod_id] or next
          value = display_value(mod, strength.to_f)
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

    def display_value(mod, strength)
      return STAMINA_DISPLAY.fetch(strength.to_i, strength) if %w[stamina enmity].include?(mod.stat)
      return SUPP_DISPLAY.fetch(mod.stat).fetch(strength.to_i, strength) if SUPP_DISPLAY.key?(mod.stat)

      strength
    end
  end
end
