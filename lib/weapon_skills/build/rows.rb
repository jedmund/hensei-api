# frozen_string_literal: true

module WeaponSkills
  module Build
    # The row compiler: one version in, its generated version-linked rows out. A port of
    # Granblue::Extractors::WeaponSkillDescriptionExtractor (description → rows) and the
    # Gameplay Notes half of ExpandedWeaponSkillImporter, without database writes, network
    # access or dependence on row order.
    #
    #   Rows.call(version, text:, registry:, curation:, notes:)  # → [BuildResult::Row]
    #
    # version   BuildResult::Version, classification resolved through the overlay's overrides
    #           (skill_modifier/skill_series/skill_size are the resolved values; skill_series
    #           is the overlay's series or Parser.series_for(text, name))
    # text      the tier's description (Rows::Description.text)
    # registry  Rows::Registry
    # curation  a CurationView
    # notes     the weapon's parsed Gameplay Notes (Rows::GameplayNotes.parse), or nil
    module Rows
      Parser = Granblue::Parsers::WeaponSkillDescriptionParser
      Row = WeaponSkills::BuildResult::Row

      SUPP_BOOSTS = %w[dmg_supp na_supp ca_supp skill_dmg_supp].freeze

      # Every value column, with the table defaults, so rows compare column for column.
      DATUM_DEFAULTS = {
        modifier: nil, boost_type: nil, series: nil, size: nil, formula_type: "flat",
        sl1: nil, sl10: nil, sl15: nil, sl20: nil, sl25: nil, coefficient: nil, max_value: nil,
        aura_boostable: false
      }.freeze
      EFFECT_DEFAULTS = {
        modifier: nil, boost_type: nil, series: nil, scaling_kind: nil, value: nil, value_unit: nil,
        per_copy_cap: nil, total_cap: nil, shared_cap_group: nil, cap_formula: nil, count_basis: nil,
        count_cap: nil, condition: {}, target_instance: nil, depends_on: [], aura_boostable: false,
        seraphic_affected: false, stacking: "additive", applies_to: "element_allies",
        battle_interaction: false, notes: nil, key_slug: nil, frame_rule: nil
      }.freeze

      # rows: [Row]; version: the version after family backfill (the classification the
      # rows were compiled against); warnings: [String]
      Result = Struct.new(:version, :rows, :warnings, keyword_init: true)

      module_function

      def call(version, text:, registry:, curation:, notes: nil)
        compile(version, text: text, registry: registry, curation: curation, notes: notes).rows
      end

      def compile(version, text:, registry:, curation:, notes: nil)
        warnings = []
        described = description_pass?(version, text)
        version, description_rows = description_rows(version, text, registry, curation, warnings)

        # Today the notes importer writes first and the description pass then purges every
        # generated row except per_grid_count/specialty_scaled, so a notes "static" row only
        # survives on a version the description pass skips. Same order here: notes rows first,
        # then the description's (first answer wins on a clash).
        rows = []
        GameplayNotes.effects(version, notes, curation: curation).each do |attrs|
          next if described && !GameplayNotes::KEPT_KINDS.include?(attrs[:scaling_kind])

          rows = add(rows, effect_row(version, attrs), warnings, source: "gameplay notes")
        end
        description_rows.each { |row| rows = add(rows, row, warnings, source: "description") }
        Result.new(version: version, rows: rows, warnings: warnings)
      end

      # Whether the description pass runs on (and so purges) this version.
      def description_pass?(version, text)
        !version.skill_name_en.to_s.match?(/[{}]/) && text.present?
      end

      # → [version (after backfill), rows]
      def description_rows(version, text, registry, curation, warnings)
        name = version.skill_name_en.to_s
        # unexpanded template garbage ("{{ #vardefineecho…") is never a real skill
        return [version, []] unless description_pass?(version, text)

        parsed = Parser.parse(text, name: name)
        pinned = curation.respond_to?(:modifier_pinned?) && curation.modifier_pinned?(version)
        version = Classification.backfill(version, parsed, registry, pinned: pinned)
        return [version, []] if parsed[:clauses].empty?

        covered = covered_boost_types(version, registry, curation)
        return [version, []] if covered.include?("*") # extraction fully suppressed

        rows = []
        parsed[:clauses].each do |clause|
          next if covered.include?(clause[:boost_type]) # canonical/curated/suppressed decide this

          row = if sl_scaled?(clause)
                  datum = datum_attributes(version, clause, registry)
                  warnings << "no curve for #{clause[:boost_type]}/#{clause[:size]}" unless datum
                  datum && datum_row(version, datum)
                elsif clause[:value]
                  effect_row(version, effect_attributes(version, clause, parsed))
                end
          rows = add(rows, row, warnings, source: "description") if row
        end
        [version, rows]
      end

      # Boost types this version already has authoritative rows for: the family's canonical
      # data and base effects, curated version-linked rows, and suppressed_boosts.
      def covered_boost_types(version, registry, curation)
        suppressed = curation.suppressed(version)
        return Set["*"] if suppressed.include?("*")

        modifier = version.skill_modifier
        covered = Set.new
        if modifier.present?
          registry.for_skill(modifier: modifier, series: version.skill_series, size: version.skill_size)
                  .each { |d| covered << d.boost_type }
          covered.merge(registry.effect_boost_types(modifier))
        end
        covered.merge(curation.curated_boost_types(version)).merge(suppressed)
      end

      # A size word with no explicit % ⇒ SL-scaled; the value comes from a canonical curve.
      def sl_scaled?(clause) = clause[:size].present? && clause[:value].nil?

      # The version's own family curve for this clause: the true per-skill value. Uses the
      # resolved classification (W1 fixed the original the same way).
      def family_curve(version, clause, registry)
        return nil if version.skill_modifier.blank?

        formula = clause[:formula_type] || "flat"
        registry.for_skill(modifier: version.skill_modifier,
                           series: clause[:series] || version.skill_series,
                           size: clause[:size] || version.skill_size)
                .find { |d| d.boost_type == clause[:boost_type] && d.formula_type == formula }
      end

      def datum_attributes(version, clause, registry)
        formula = clause[:formula_type] || "flat"
        curve = family_curve(version, clause, registry) ||
                registry.canonical_curve(boost_type: clause[:boost_type], size: clause[:size], formula_type: formula,
                                         series: clause[:series] || version.skill_series)
        return nil unless curve

        DATUM_DEFAULTS.merge(
          modifier: version.skill_name_en, boost_type: clause[:boost_type], series: clause[:series],
          size: clause[:size], formula_type: formula,
          sl1: curve.sl1, sl10: curve.sl10, sl15: curve.sl15, sl20: curve.sl20, sl25: curve.sl25,
          coefficient: curve.coefficient, max_value: curve.max_value, aura_boostable: false
        )
      end

      def effect_attributes(version, clause, parsed)
        { modifier: version.skill_name_en, boost_type: clause[:boost_type], series: clause[:series],
          scaling_kind: clause[:condition] ? "conditional_flat" : "static", value: clause[:value],
          value_unit: SUPP_BOOSTS.include?(clause[:boost_type]) ? "flat" : "percent",
          condition: clause[:condition] || {},
          applies_to: parsed[:mc_only] ? "mc_only" : "element_allies", stacking: "additive" }
      end

      def datum_row(version, attrs)
        Row.new(version_identity: version.identity, kind: :datum, boost_type: attrs[:boost_type],
                condition: nil, attributes: attrs)
      end

      def effect_row(version, attrs)
        attrs = EFFECT_DEFAULTS.merge(attrs)
        Row.new(version_identity: version.identity, kind: :effect, boost_type: attrs[:boost_type],
                condition: attrs[:condition], attributes: attrs)
      end

      # The first answer wins, as it did when the database's uniqueness validation rejected
      # the second create!. Also drops what the effect validations would reject.
      def add(rows, row, warnings, source:)
        if row.kind == :effect && !GridDamage::GridComposition.valid_count_condition?(row.condition)
          warnings << "#{source}: invalid count condition on #{row.boost_type}: #{row.condition.inspect}"
          return rows
        end
        clash = rows.find { |r| same_record?(r, row) || r.identity == row.identity }
        if clash
          warnings << "#{source}: #{row.kind} #{row.boost_type} #{row.condition.inspect} duplicates an earlier row"
          return rows
        end
        rows + [row]
      end

      # The tables' uniqueness scopes (modifier is the skill name for every generated row).
      def same_record?(row, other)
        return false unless row.kind == other.kind

        keys = row.kind == :datum ? %i[boost_type series size] : %i[boost_type scaling_kind condition]
        row.attributes.values_at(*keys) == other.attributes.values_at(*keys)
      end
    end
  end
end
