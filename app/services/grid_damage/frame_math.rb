# frozen_string_literal: true

module GridDamage
  # Phase 4 of the grid damage calculator: combine the per-frame weapon-skill totals
  # (from the aggregator) with summon auras and Exalto into the multiplicative boost the
  # grid contributes — the panel's per-series "Enhancements" and the NormalOmegaEX × Elemental product.
  #
  # Per doc 01: within a frame the summon aura and Exalto stack ADDITIVELY inside the
  # weapon-mod multiplier, and the frames MULTIPLY:
  #   Normal ATK boost = 1 + NormATKmod × (1 + Optimus aura + Optimus Exalto) + NormSummon aura
  #   Omega ATK boost  = 1 + OmegaATKmod × (1 + Omega aura + Omega Exalto)
  #   EX ATK boost     = 1 + EX ATK mod                              (no ordinary aura)
  #   (Enmity/Stamina mirror the ATK form per frame)
  #   NormalOmegaEX = ∏(ATK × Enmity × Stamina over normal/omega/ex) − Fixed ATK mods
  #   Elemental     = 1 + superiority + elemental ATK auras + Progression(≤75%)
  #
  # All mod/aura inputs are percent-numbers (58.5 = 58.5%). Outputs are multipliers.
  module FrameMath
    module_function

    SUPERIORITY = { superior: 50.0, inferior: -25.0, neutral: 0.0 }.freeze
    PROGRESSION_CAP = 75.0

    # normal/omega/ex: { atk:, enmity:, stamina: } percent-number sums for that frame.
    # auras:  { optimus:, omega:, elemental:, normal_summon: } (percent).
    # exalto: { optimus:, omega: } (percent; already capped 90/100 by the aggregator).
    # advantage: :superior | :inferior | :neutral. progression: total e_atk_prog %.
    # Returns per-frame boosts, the NormalOmegaEX composite, the Elemental boost, and
    # their product (the grid's damage multiplier vs base ATK).
    def compute(normal: {}, omega: {}, ex: {}, auras: {}, exalto: {},
                advantage: :neutral, progression: 0.0, fixed_atk: 0.0)
      n = frame(normal, auras[:optimus].to_f + exalto[:optimus].to_f, extra_atk: auras[:normal_summon].to_f)
      o = frame(omega, auras[:omega].to_f + exalto[:omega].to_f)
      x = frame(ex, 0.0)

      composite = (n[:product] * o[:product] * x[:product]) - (fixed_atk.to_f / 100.0)
      elemental = elemental_boost(auras[:elemental].to_f, advantage, progression)

      {
        normal: n, omega: o, ex: x,
        normal_omega_ex: composite,
        elemental: elemental,
        grid_multiplier: composite * elemental
      }
    end

    # One frame's ATK/Enmity/Stamina boosts and their product. `amp_pct` is the additive
    # (aura + Exalto) that multiplies the weapon mods; `extra_atk` is added directly
    # (NormSummon/Bahamut/Ultima), only on the Normal frame.
    def frame(mods, amp_pct, extra_atk: 0.0)
      amp = 1.0 + (amp_pct / 100.0)
      atk     = 1.0 + ((mods[:atk].to_f / 100.0) * amp) + (extra_atk / 100.0)
      enmity  = 1.0 + ((mods[:enmity].to_f / 100.0) * amp)
      stamina = 1.0 + ((mods[:stamina].to_f / 100.0) * amp)
      { atk: atk, enmity: enmity, stamina: stamina, product: atk * enmity * stamina }
    end

    def elemental_boost(elemental_aura_pct, advantage, progression_pct)
      superiority = SUPERIORITY.fetch(advantage, 0.0)
      prog = [progression_pct.to_f, PROGRESSION_CAP].min
      1.0 + ((superiority + elemental_aura_pct.to_f + prog) / 100.0)
    end

    # Convenience: per-frame "Enhancement %" the in-game panel shows = (ATK boost − 1)×100.
    def enhancement_percents(result)
      %i[normal omega ex].to_h { |f| [f, ((result[f][:atk] - 1.0) * 100.0).round(1)] }
    end

    private_class_method :frame, :elemental_boost
  end
end
