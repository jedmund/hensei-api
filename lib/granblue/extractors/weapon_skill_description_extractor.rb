# frozen_string_literal: true

module Granblue
  module Extractors
    # Resolves weapon-skill versions that have no canonical (modifier-keyed) data or effects, by
    # parsing the skill DESCRIPTION (never the icon) into clauses and writing per-version rows:
    #   - SL-scaled stat boosts (size word, no explicit %) → weapon_skill_data, reusing the
    #     canonical (boost_type, series, size) SL-curve.
    #   - flat / conditional / supplement / main-weapon clauses → weapon_skill_effects.
    # The version's skill_series is set from the parse so the frame resolves without the icon.
    class WeaponSkillDescriptionExtractor
      Parser = Granblue::Parsers::WeaponSkillDescriptionParser

      SUPP_BOOSTS = %w[dmg_supp na_supp ca_supp skill_dmg_supp].freeze

      def self.run(dry_run: false)
        stats = Hash.new(0)
        @weapon_cache = {}
        WeaponSkillVersion.includes(:skill, :weapon_skill).find_each do |v|
          skill = v.skill
          desc = full_description(v).presence || skill&.description_en
          next if desc.blank?

          # 1. Re-attribute the frame from the description (never the icon), for EVERY version.
          series = Parser.series_for(desc, skill&.name_en)
          if v.skill_series != series
            v.update_columns(skill_series: series) unless dry_run
            stats[:reattributed_series] += 1
          end

          # 2. For EVERY version, write version-linked rows for the boost_types the canonical
          #    modifier-keyed data/effects DON'T already cover. Fully unmodeled skills get all
          #    their boosts; composite skills (e.g. Restraint = DA canonical + Critical missing)
          #    get just the missing halves.
          parsed = Parser.parse(desc, name: skill&.name_en)
          if parsed[:clauses].empty?
            stats[parsed[:skip] ? "skip_#{parsed[:skip]}".to_sym : :no_clause] += 1
            next
          end

          covered = canonical_boost_types(v)
          apply(v, skill, parsed, covered, stats) unless dry_run
          stats[covered.empty? ? :resolved : :completed] += 1
        end
        stats
      end

      # boost_types the canonical (modifier-keyed) data/effects already provide for this version.
      def self.canonical_boost_types(version)
        data = WeaponSkillDatum.for_skill(modifier: version.skill_modifier, series: version.skill_series,
                                          size: version.skill_size).pluck(:boost_type)
        effects = version.skill_modifier.present? ?
          WeaponSkillEffect.for_skill(modifier: version.skill_modifier).base_effects.pluck(:boost_type) : []
        (data + effects).to_set
      end

      # The FULL skill description from the weapon's wiki_raw (sN_desc) — it carries the numeric
      # values that the abbreviated Skill#description_en (ensN_desc) drops (e.g. "…by 100,000,
      # 10% boost to damage cap"). Matched by skill position + the tier whose name == this
      # version's skill name (base / 4s / 5s).
      def self.full_description(version)
        ws = version.weapon_skill or return nil
        raw = weapon_wiki_raw(ws.weapon_granblue_id)
        return nil if raw.blank?

        pos = ws.position.to_i + 1
        name = version.skill&.name_en
        ["", "4s", "5s"].each do |tier|
          field = "s#{pos}#{tier.empty? ? '' : "_#{tier}"}"
          return wiki_field(raw, "#{field}_desc") if wiki_field(raw, "#{field}_name") == name
        end
        nil
      end

      def self.weapon_wiki_raw(granblue_id)
        @weapon_cache[granblue_id] ||= Weapon.where(granblue_id: granblue_id).pick(:wiki_raw).to_s
      end

      def self.wiki_field(raw, field)
        raw[/\|#{Regexp.escape(field)}=(.*?)(?:\n\||\z)/m, 1]&.strip
      end

      # scaling_kinds owned by the gameplay-notes importer (the numbers the prose lacks) — the
      # description pass must not wipe them.
      NOTES_KINDS = %w[per_grid_count specialty_scaled].freeze

      def self.apply(version, skill, parsed, covered, stats)
        WeaponSkillDatum.where(weapon_skill_version_id: version.id).delete_all
        WeaponSkillEffect.where(weapon_skill_version_id: version.id).where.not(scaling_kind: NOTES_KINDS).delete_all

        series = parsed[:clauses].filter_map { |c| c[:series] }.first || "ex"
        version.update_columns(skill_series: series) if version.skill_series != series

        parsed[:clauses].each do |c|
          next if covered.include?(c[:boost_type]) # canonical data/effects already provide this

          if sl_scaled?(c) && write_data(version, skill, c)
            stats[:data_rows] += 1
          elsif c[:value]
            write_effect(version, skill, c, parsed)
            stats[:effect_rows] += 1
          else
            stats[:gap_no_curve_no_value] += 1 # SL-scaled clause with no canonical curve & no %
          end
        rescue ActiveRecord::RecordNotUnique
          stats[:dup_clause] += 1 # two clauses collapse to the same (boost_type, …) for this version
        rescue ActiveRecord::RecordInvalid => e
          stats[:invalid] += 1 # log + skip rather than halt the whole run
          Rails.logger.warn("desc-extract invalid (#{skill.name_en}): #{e.message}")
        end
      end

      # A size word with no explicit % ⇒ SL-scaled; the value comes from the canonical curve.
      def self.sl_scaled?(clause)
        clause[:size].present? && clause[:value].nil?
      end

      def self.write_data(version, skill, clause)
        curve = WeaponSkillDatum.canonical_curve(
          boost_type: clause[:boost_type], size: clause[:size],
          formula_type: clause[:formula_type] || "flat"
        )
        return nil unless curve

        WeaponSkillDatum.create!(
          weapon_skill_version_id: version.id, modifier: skill.name_en,
          boost_type: clause[:boost_type], series: clause[:series], size: clause[:size],
          formula_type: clause[:formula_type] || "flat",
          sl1: curve.sl1, sl10: curve.sl10, sl15: curve.sl15, sl20: curve.sl20, sl25: curve.sl25,
          coefficient: curve.coefficient, max_value: curve.max_value, aura_boostable: false
        )
      end

      def self.write_effect(version, skill, clause, parsed)
        WeaponSkillEffect.create!(
          weapon_skill_version_id: version.id, modifier: skill.name_en,
          boost_type: clause[:boost_type], series: clause[:series],
          scaling_kind: clause[:condition] ? "conditional_flat" : "static",
          value: clause[:value],
          value_unit: SUPP_BOOSTS.include?(clause[:boost_type]) ? "flat" : "percent",
          condition: clause[:condition] || {},
          applies_to: parsed[:mc_only] ? "mc_only" : "element_allies", stacking: "additive"
        )
      end

      private_class_method :canonical_boost_types, :full_description, :weapon_wiki_raw, :wiki_field,
                           :apply, :sl_scaled?, :write_data, :write_effect
    end
  end
end
