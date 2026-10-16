# frozen_string_literal: true

module GridDamage
  # Befoulments — the Odious weapons' negative skills — land on the panel as "Hit"
  # lines: each grid copy's stored CURRENT (post-exorcision) value, summed per stat
  # and never amplified (qBOvon: ATK Hit -17.5 = -9.9 + -7.6 from two Demonspears,
  # exact). A multiattack befoulment hits both rate lines at full strength.
  module BefoulmentContributions
    module_function

    STAT_KEYS = {
      "atk" => %w[atk_hit],
      "da_ta" => %w[da_hit ta_hit],
      "ability_dmg" => %w[skill_dmg_hit],
      "ca_dmg" => %w[ca_dmg_hit],
      "hp" => %w[hp_hit],
      "def" => %w[def_hit],
      "debuff_success" => %w[debuff_hit],
      "dot" => %w[turn_dmg_hit]
    }.freeze

    def for_party(party)
      party.weapons.includes(:befoulment_modifier).flat_map do |gw|
        mod = gw.befoulment_modifier
        next [] unless mod && gw.befoulment_strength

        keys = STAT_KEYS[mod.stat] or next []
        keys.map do |key|
          Aggregator::Contribution.new(
            # Strength is stored as a magnitude by the extension import and signed by older
            # parties; the panel shows the modifier's sign either way (ATK Hit -14.1).
            boost_type: key, series: nil, value: mod.polarity * gw.befoulment_strength.to_f.abs,
            main_hand_only: false, mainhand: gw.mainhand, amplifiable: false,
            source_ids: [gw.id],
            source_label: { en: mod.name_en, ja: mod.name_jp }
          )
        end
      end
    end
  end
end
