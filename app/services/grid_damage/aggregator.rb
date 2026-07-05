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

    # One skill's resolved contribution to the grid. `shared_cap_group`/`cap` are set by
    # effect contributions that share a ceiling across skills (e.g. voltage_wrath_grandepic
    # 80%, dmg_supp_shared 100k).
    # `amplifiable` is false for sources the summon-aura enhancement does NOT scale (weapon
    # awakenings are flat panel bonuses); nil/true means the enhancement applies.
    # `source_ids` names the grid weapons a contribution came from (UI highlighting).
    Contribution = Struct.new(:boost_type, :series, :value, :main_hand_only, :mainhand,
                              :shared_cap_group, :cap, :amplifiable, :source_ids,
                              keyword_init: true)

    # An aggregated boost_type. `by_series` is set only for multiplicative_by_series;
    # otherwise `total` is the (capped) value. `raw` is the pre-cap amount. `source_map`
    # maps series (nil for seriesless) → contributing grid weapon ids.
    Result = Struct.new(:boost_type, :rule, :total, :by_series, :raw, :cap, :cap_is_flat, :capped,
                        :source_map, keyword_init: true)

    # contributions: Array<Contribution>
    # boost_types:   { key => metadata } where metadata responds to
    #                stacking_rule / grid_cap / cap_is_flat (defaults to the DB table)
    # → { boost_type => Result }
    def aggregate(contributions, boost_types: load_boost_types)
      active = contributions.reject do |c|
        c.value.nil? || (c.main_hand_only && !c.mainhand)
      end
      active = apply_shared_caps(active)

      active.group_by(&:boost_type).transform_values do |group|
        build_result(group, boost_types[group.first.boost_type])
      end
    end

    # Collapse each shared_cap_group's members to a single contribution capped at the
    # group's ceiling (e.g. Voltage+Wrath+Grand Epic share 80%). Members of one group
    # share a boost_type/series, so the capped total stands in for them.
    def apply_shared_caps(contributions)
      grouped, ungrouped = contributions.partition { |c| c.shared_cap_group.present? }
      pooled = grouped.group_by(&:shared_cap_group).flat_map do |_group, members|
        cap = members.filter_map(&:cap).min
        total = members.sum { |c| c.value.to_f }
        if cap && total > cap
          [Contribution.new(boost_type: members.first.boost_type, series: members.first.series,
                            value: cap, mainhand: true,
                            source_ids: members.flat_map { |c| Array(c.source_ids) }.uniq)]
        else
          members
        end
      end
      ungrouped + pooled
    end

    def build_result(group, meta)
      boost_type = group.first.boost_type
      rule = meta&.stacking_rule || "additive"
      cap = meta&.grid_cap&.to_f
      flat = meta&.cap_is_flat || false
      sources = source_map(group)

      case rule
      when "multiplicative_by_series"
        by_series = group.group_by(&:series).transform_values { |g| sum(g) }
        Result.new(boost_type: boost_type, rule: rule, by_series: by_series, total: by_series.values.sum,
                   raw: by_series.values.sum, cap: nil, cap_is_flat: flat, capped: false,
                   source_map: sources)
      when "highest_only"
        capped(boost_type, rule, group.map(&:value).max, cap, flat, sources)
      else
        capped(boost_type, rule, sum(group), cap, flat, sources)
      end
    end

    def capped(boost_type, rule, raw, cap, flat, sources = {})
      total = cap ? [raw, cap].min : raw
      Result.new(boost_type: boost_type, rule: rule, total: total, by_series: nil, raw: raw, cap: cap,
                 cap_is_flat: flat, capped: !cap.nil? && raw > cap, source_map: sources)
    end

    def source_map(group)
      group.group_by(&:series).transform_values do |g|
        g.flat_map { |c| Array(c.source_ids) }.uniq
      end
    end

    def sum(group)
      group.sum { |c| c.value.to_f }
    end

    def load_boost_types
      WeaponSkillBoostType.all.index_by(&:key)
    end

    private_class_method :build_result, :capped, :sum, :source_map, :load_boost_types
  end
end
