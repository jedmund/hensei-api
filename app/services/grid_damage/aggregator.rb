# frozen_string_literal: true

module GridDamage
  # Phase 2 of the grid damage calculator: combine the per-skill values from
  # GridDamage::Scaling into per-boost_type totals — the game's "Weapon Skill Boosts"
  # list. Applies each boost_type's stacking_rule and grid_cap, and gates main-hand-only
  # skills.
  #
  #   additive                  → sum the contributions (the common case)
  #   highest_only              → keep the single largest (e.g. elem_amplify)
  #   multiplicative_by_series  → keep per-series subtotals (Normal/Omega/EX), which the
  #                               frame math (Phase 4) multiplies together; not capped here
  #
  # shared_cap_group (several skills sharing one ceiling) lives on weapon_skill_effects,
  # so it's handled with the conditional-effects track in Phase 5.
  module Aggregator
    module_function

    # One skill's resolved contribution to the grid.
    Contribution = Struct.new(:boost_type, :series, :value, :main_hand_only, :mainhand,
                              keyword_init: true)

    # An aggregated boost_type. `by_series` is set only for multiplicative_by_series;
    # otherwise `total` is the (capped) value. `raw` is the pre-cap amount.
    Result = Struct.new(:boost_type, :rule, :total, :by_series, :raw, :cap, :cap_is_flat, :capped,
                        keyword_init: true)

    # contributions: Array<Contribution>
    # boost_types:   { key => metadata } where metadata responds to
    #                stacking_rule / grid_cap / cap_is_flat (defaults to the DB table)
    # → { boost_type => Result }
    def aggregate(contributions, boost_types: load_boost_types)
      active = contributions.reject do |c|
        c.value.nil? || (c.main_hand_only && !c.mainhand)
      end

      active.group_by(&:boost_type).transform_values do |group|
        build_result(group, boost_types[group.first.boost_type])
      end
    end

    def build_result(group, meta)
      boost_type = group.first.boost_type
      rule = meta&.stacking_rule || "additive"
      cap = meta&.grid_cap&.to_f
      flat = meta&.cap_is_flat || false

      case rule
      when "multiplicative_by_series"
        by_series = group.group_by(&:series).transform_values { |g| sum(g) }
        Result.new(boost_type:, rule:, by_series:, total: by_series.values.sum,
                   raw: by_series.values.sum, cap: nil, cap_is_flat: flat, capped: false)
      when "highest_only"
        capped(boost_type, rule, group.map(&:value).max, cap, flat)
      else
        capped(boost_type, rule, sum(group), cap, flat)
      end
    end

    def capped(boost_type, rule, raw, cap, flat)
      total = cap ? [raw, cap].min : raw
      Result.new(boost_type:, rule:, total:, by_series: nil, raw:, cap:,
                 cap_is_flat: flat, capped: !cap.nil? && raw > cap)
    end

    def sum(group)
      group.sum { |c| c.value.to_f }
    end

    def load_boost_types
      WeaponSkillBoostType.all.index_by(&:key)
    end

    private_class_method :build_result, :capped, :sum, :load_boost_types
  end
end
