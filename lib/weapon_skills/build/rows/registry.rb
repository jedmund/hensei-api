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

        # A canonical base effect: only its (modifier, boost_type) matter to the row compiler.
        Effect = Struct.new(:modifier, :boost_type, keyword_init: true)

        CURVE_COLUMNS = %i[modifier boost_type series size formula_type sl1 sl10 sl15 sl20 sl25
                           coefficient max_value].freeze

        SERIES_FALLBACK = WeaponSkillDatum::SERIES_FALLBACK

        def self.from_database
          data = WeaponSkillDatum.canonical.order(:id).pluck(*CURVE_COLUMNS).map do |values|
            Curve.new(**CURVE_COLUMNS.zip(values).to_h)
          end
          effects = WeaponSkillEffect.base_effects.order(:id).pluck(:modifier, :boost_type).map do |m, b|
            Effect.new(modifier: m, boost_type: b)
          end
          new(data: data, effects: effects)
        end

        attr_reader :data, :effects

        def initialize(data:, effects:)
          @data = data.map { |d| d.is_a?(Curve) ? d : Curve.new(**d.to_h.slice(*CURVE_COLUMNS)) }.freeze
          @effects = effects.map { |e| e.is_a?(Effect) ? e : Effect.new(**e.to_h.slice(:modifier, :boost_type)) }.freeze
          @data_by_modifier = @data.group_by(&:modifier)
          @effect_boosts_by_modifier = @effects.group_by(&:modifier).transform_values { |es| es.map(&:boost_type).to_set }
          @curves_by_tier = @data.group_by { |d| [d.boost_type, d.size, d.formula_type] }
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

        # WeaponSkillDatum.canonical_curve: the strongest canonical curve for a tier, across
        # families. The model's tie-break (sl15, completeness, modifier) can still tie when one
        # modifier has the tier in two series (Stamina medium: normal 65 / omega 60.4), so it
        # continues with the caller's series (exact, then SERIES_FALLBACK), then the row's values.
        def canonical_curve(boost_type:, size:, formula_type: "flat", series: nil)
          compatible = SERIES_FALLBACK.fetch(series, [series])
          @curves_by_tier.fetch([boost_type, size, formula_type], []).max_by do |d|
            [d.sl15.to_f, d.levels.compact.size, d.modifier.to_s,
             -(compatible.index(d.series) || compatible.size)] + d.tie_key
          end
        end

        # A family with any canonical data or base effect (the extractor's canonical_family?).
        def canonical_family?(modifier)
          @data_by_modifier.key?(modifier) || @effect_boosts_by_modifier.key?(modifier)
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
