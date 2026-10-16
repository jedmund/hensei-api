# frozen_string_literal: true

module WeaponSkills
  module Build
    module Rows
      # Read-only, in-memory view of the canonical (modifier-keyed) skill data and effects
      # the row compiler resolves against. Loaded once per build; no queries after that.
      #
      # Ports WeaponSkillDatum.for_skill / .canonical_curve and the extractor's
      # canonical_family? with one change: every "pick one of several candidates" ends in a
      # total ordering over the row's values, so the answer never depends on row order.
      class Registry
        # rubocop:disable Lint/StructNewOverride -- the table's column is "size"
        Curve = Struct.new(:modifier, :boost_type, :series, :size, :formula_type,
                           :sl1, :sl10, :sl15, :sl20, :sl25, :coefficient, :max_value,
                           keyword_init: true) do
          def levels = [sl1, sl10, sl15, sl20, sl25]

          # Value-only tie-break key, comparable across any two curves (no nils).
          def tie_key
            [formula_type.to_s, series.to_s, size.to_s, modifier.to_s] + levels.map { |v| v.nil? ? -Float::INFINITY : v.to_f } +
              [coefficient.to_f, max_value.to_f]
          end
        end

        # rubocop:enable Lint/StructNewOverride

        # A canonical base effect: only its (modifier, boost_type) matter to the row compiler.
        Effect = Struct.new(:modifier, :boost_type, keyword_init: true)

        CURVE_COLUMNS = %i[modifier boost_type series size formula_type sl1 sl10 sl15 sl20 sl25
                           coefficient max_value].freeze

        SERIES_FALLBACK = WeaponSkillDatum::SERIES_FALLBACK

        # The family whose curve stands for a boost type's plain "<size> boost" when a skill
        # has no family of its own: the gbf.wiki template for that boost alone
        # (Template:Weapon Skills/Might is ATK, Aegis is HP, Trium is DA and TA, …).
        BASE_FAMILIES = {
          "atk" => "Might", "hp" => "Aegis", "da" => "Trium", "ta" => "Trium", "critical" => "Verity",
          "enmity" => "Enmity", "stamina" => "Stamina", "heal_cap" => "Healing"
        }.freeze

        def self.from_database
          data = WeaponSkillDatum.canonical.order(:id).pluck(*CURVE_COLUMNS).map do |values|
            Curve.new(**CURVE_COLUMNS.zip(values).to_h)
          end
          effects = WeaponSkillEffect.base_effects.order(:id).pluck(:modifier, :boost_type).map do |m, b|
            Effect.new(modifier: m, boost_type: b)
          end
          curve_effects = WeaponSkillEffect.base_effects.where(scaling_kind: "weapon_skill_curve").distinct.pluck(:modifier)
          new(data: data, effects: effects, curve_effect_modifiers: curve_effects)
        end

        attr_reader :data, :effects

        # curve_effect_modifiers: families with a weapon_skill_curve base effect (they scale with
        # skill level without curve data).
        def initialize(data:, effects:, curve_effect_modifiers: [])
          @data = data.map { |d| d.is_a?(Curve) ? d : Curve.new(**d.to_h.slice(*CURVE_COLUMNS)) }.freeze
          @effects = effects.map { |e| e.is_a?(Effect) ? e : Effect.new(**e.to_h.slice(:modifier, :boost_type)) }.freeze
          @data_by_modifier = @data.group_by(&:modifier)
          @effect_boosts_by_modifier = @effects.group_by(&:modifier).transform_values { |es| es.to_set(&:boost_type) }
          @curves_by_tier = @data.group_by { |d| [d.boost_type, d.size, d.formula_type] }
          @curve_effect_modifiers = curve_effect_modifiers.to_set.freeze
        end

        # WeaponSkillDatum.for_skill: at most one canonical curve per boost_type for a
        # (modifier, series, size). Returns an Array.
        def for_skill(modifier:, series: nil, size: nil)
          rows = @data_by_modifier.fetch(modifier, [])
          rows = rows.select { |d| d.size.nil? || d.size == size } if size
          compatible = SERIES_FALLBACK.fetch(series, [series])

          rows.group_by(&:boost_type).sort_by(&:first).filter_map do |_, group|
            group = series_matched(group, compatible) if series.present?
            next if group.empty?
            next if size.nil? && group.filter_map(&:size).uniq.many? # ambiguous — don't guess

            group.max_by do |d|
              [d.size == size ? 1 : 0, -(compatible.index(d.series) || compatible.size), d.sl15.to_f] + d.tie_key
            end
          end
        end

        # The fallback curve for an SL-scaled clause whose skill has no family of its own.
        # Candidates are the tier's canonical curves in a series the skill can take: its own,
        # then its SERIES_FALLBACK. A curve from any other series never qualifies (an EX skill
        # never borrows a Taboo curve); with no candidate the answer is nil. Among candidates:
        # the nearest series, then the boost type's base family (BASE_FAMILIES), then
        # completeness, then the modifier and the row's values as a fixed key. The size of the
        # values never decides (WeaponSkillDatum.canonical_curve's "strongest curve" rule let
        # the Taboo family's ×1.2 values win for every EX skill).
        def canonical_curve(boost_type:, size:, formula_type: "flat", series: nil)
          compatible = SERIES_FALLBACK.fetch(series, [series])
          base = BASE_FAMILIES[boost_type]
          @curves_by_tier.fetch([boost_type, size, formula_type], [])
                         .select { |d| compatible.include?(d.series) }
                         .min_by do |d|
                           [compatible.index(d.series), d.modifier == base ? 0 : 1, -d.levels.compact.size,
                            d.modifier.to_s] + d.tie_key
                         end
        end

        # A family with any canonical data or base effect (the extractor's canonical_family?).
        def canonical_family?(modifier)
          @data_by_modifier.key?(modifier) || @effect_boosts_by_modifier.key?(modifier)
        end

        def curve_effect?(modifier) = @curve_effect_modifiers.include?(modifier)

        # A family whose skills have a skill level: some canonical curve of it changes with
        # skill level (per-level values, or a formula coefficient that takes the skill level,
        # as Stamina's does), or it has a weapon_skill_curve base effect. A family with only
        # fixed values (Godblade, Voltage II, Exalto, …) has none.
        def leveled_family?(modifier)
          curve_effect?(modifier) || @data_by_modifier.fetch(modifier, []).any? do |d|
            d.levels.compact.uniq.size > 1 || !d.coefficient.nil?
          end
        end

        def effect_boost_types(modifier)
          @effect_boosts_by_modifier.fetch(modifier, Set.new)
        end

        private

        def series_matched(group, compatible)
          matched = group.select { |d| d.series.nil? || compatible.include?(d.series) }
          return matched if matched.any?

          lone = group.map(&:series).uniq
          lone.size == 1 && lone.first != "normal_omega" ? group : []
        end
      end
    end
  end
end
