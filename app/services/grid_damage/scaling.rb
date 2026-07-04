# frozen_string_literal: true

module GridDamage
  # Phase 1 of the grid damage calculator: the value of a single weapon skill at a given
  # skill level and battle state, per `formula_type`. Pure functions over a
  # WeaponSkillDatum (or any object exposing sl1/sl10/sl15/sl20/sl25/coefficient/
  # max_value/formula_type). Values are in the data's own units (percent-numbers for ATK/
  # DA/…; absolute for supplemental/shield) — the aggregator interprets units per
  # boost_type. Formulas reproduce gbf.wiki (see docs/damage/02, /08, /12).
  module Scaling
    module_function

    SL_ANCHORS = [1, 10, 15, 20, 25].freeze
    STAMINA_EXP = 2.9
    STAMINA_OFFSET = 2.1
    STAMINA_HP_FLOOR = 25 # below 25% HP, Stamina is constant at its 25%-HP value

    # The skill's contribution at (skill_level, state).
    #   state: { hp_percent: 0..100, turn: Integer }
    # Returns a Float in the datum's units, or nil if undefined.
    def value(datum, skill_level:, hp_percent: 100.0, turn: 1)
      case datum.formula_type
      when "enmity"      then enmity(datum, skill_level, hp_percent)
      when "stamina"     then stamina(datum, skill_level, hp_percent)
      when "progression" then progression(datum, skill_level, turn)
      else                    flat(datum, skill_level) # "flat", "garrison" (flat DEF), nil
      end
    end

    # Linear interpolation across the defined SL anchors; clamps outside the defined range.
    def flat(datum, skill_level)
      points = SL_ANCHORS.map { |sl| [sl, anchor(datum, sl)] }.reject { |(_, v)| v.nil? }
      return nil if points.empty?

      lo = points.first
      hi = points.last
      return lo.last if skill_level <= lo.first
      return hi.last if skill_level >= hi.first

      left = points.select { |(sl, _)| sl <= skill_level }.last
      right = points.find { |(sl, _)| sl >= skill_level }
      return left.last if left.first == right.first

      t = (skill_level - left.first).to_f / (right.first - left.first)
      left.last + ((right.last - left.last) * t)
    end

    # Enmity: stronger as HP drops. Modifier = the SL value; r = missing-HP fraction.
    #   strength = Modifier × ((1 + 2r) × r)    (0 at full HP, 3×Modifier near 0 HP)
    def enmity(datum, skill_level, hp_percent)
      modifier = flat(datum, skill_level)
      return nil if modifier.nil?

      r = 1.0 - (hp_percent.to_f / 100.0)
      r = r.clamp(0.0, 1.0)
      modifier * ((1 + (2 * r)) * r)
    end

    # Stamina: stronger at high HP. Per the wiki, strength = (HP% / (Coefficient −
    # SL-adjustment))^2.9 + 2.1, with HP% floored at 25%. The data stores `coefficient`
    # (per size/series); the SL-adjustment grows with skill level (piecewise, and
    # size-dependent for Small at SL 11–15).
    def stamina(datum, skill_level, hp_percent)
      coef = datum.coefficient&.to_f
      return flat(datum, skill_level) if coef.nil? || coef <= 0 # non-coefficient fallback

      denom = coef - stamina_adjustment(skill_level, small: datum.size == "small")
      return nil if denom <= 0

      h = hp_percent.to_f.clamp(STAMINA_HP_FLOOR, 100)
      ((h / denom)**STAMINA_EXP) + STAMINA_OFFSET
    end

    # The amount subtracted from the Coefficient at a given skill level (gbf.wiki).
    def stamina_adjustment(skill_level, small: false)
      sl = skill_level
      if small && sl > 10 then 10 + (2 * (sl - 10))
      elsif sl <= 15 then sl
      elsif sl <= 20 then 15 + (0.4 * (sl - 15))
      else
        (17 + (0.34 * (sl - 20))).floor(1) # trunc to 1 decimal (SL 25 -> 18.7)
      end
    end

    # Progression: Elemental ATK accrued per turn, capped at the skill's individual
    # maximum (max_value). The global 75% Progression cap is applied at aggregation.
    def progression(datum, skill_level, turn)
      per_turn = flat(datum, skill_level)
      return nil if per_turn.nil?

      total = per_turn * [turn, 0].max
      cap = datum.max_value
      cap ? [total, cap.to_f].min : total
    end

    def anchor(datum, skill_level)
      v = datum.public_send(:"sl#{skill_level}")
      v&.to_f
    end
    private_class_method :anchor
  end
end
