# frozen_string_literal: true

module Granblue
  module Extractors
    # Auto-generates the element-agnostic key→skill effects (Dark Opus pendulum/teluma/chain,
    # Destroyer anklet, …) from the weapon-series summary pages, replacing hand-curated key data.
    #
    # Pipeline (each piece is reused, nothing bespoke):
    #   SeriesKeyParser            → { key item name, skill prose } per series page
    #   name_en bridge             → the matching WeaponKey.slug
    #   WeaponSkillDescriptionParser → boost-type clauses (same parser as weapon skills)
    #   canonical_curve            → values for size-word clauses (no explicit %)
    # → version-less, key_slug-scoped weapon_skill_effects (what GridDamage::KeySkills consumes).
    class KeySkillExtractor
      SERIES_PAGES = ["Dark Opus Weapons", "Destroyer Weapons", "Draconic Weapons",
                      "Draconic Weapons Provenance", "Ultima Weapons"].freeze
      Parser = Granblue::Parsers::SeriesKeyParser
      DescParser = Granblue::Parsers::WeaponSkillDescriptionParser
      GameplayNotesParser = Granblue::Parsers::GameplayNotesParser
      SUPP_BOOSTS = WeaponSkillDescriptionExtractor::SUPP_BOOSTS
      # Key-granted supplements land on the panel's second-stack "(Sp.)" lines.
      KEY_SUPP_SP = { "na_supp" => "na_supp_sp", "ca_supp" => "ca_supp_sp",
                      "skill_dmg_supp" => "skill_supp_sp" }.freeze

      def self.run(dry_run: false)
        wiki = Granblue::Parsers::Wiki.new
        stats = Hash.new(0)
        preview = []

        SERIES_PAGES.each do |page|
          wikitext = fetch(wiki, page) or (stats[:fetch_failed] += 1
                                           next)
          Parser.parse(wikitext).each do |entry|
            key = WeaponKey.where("lower(name_en) = ?", entry[:name].downcase).first
            next stats[:unmatched_key] += 1 unless key

            effects = clause_effects(key.slug, entry[:name], entry[:skill_text])
            effects = boost_level_effects(key.slug, entry[:name], entry[:effect_text]) if effects.empty?
            next stats[:no_value] += 1 if effects.empty?

            preview << { slug: key.slug, name: entry[:name],
                         effects: effects.map { |e| "#{e[:boost_type]}=#{e[:value]}" } }
            persist(key.slug, effects, stats) unless dry_run
          end
        end
        [stats, preview]
      end

      # skill prose → key-scoped effect attribute hashes (explicit % or size-curve value).
      # A boost stated twice (the series tables repeat the skill prose next to a concrete
      # "20% ATK Up" trade column) keeps the EXPLICIT value — it's the authoritative SL20 number.
      def self.clause_effects(slug, name, skill_text)
        # Some keys (Destroyer anklets) gate the whole skill on "…280% or above" inline.
        gate = { "type" => "boost_level", "gte" => 280 } if /280%\s*or above/i.match?(skill_text.to_s)

        effects = DescParser.parse(skill_text, name: name)[:clauses].filter_map do |c|
          boost = c[:boost_type]
          value = c[:value] || curve_value(c)
          if value.nil? && SUPP_BOOSTS.include?(boost)
            # "supplement … damage (Damage cap: 20,000)" — the cap is the panel value
            value = skill_text[/damage cap:\s*([\d,]+)/i, 1]&.delete(",")&.to_f
          end
          next unless value

          # Key-granted supplements are the panel's Special stack — "N.A. Supp. (Sp.)"
          # (5JPIJg: the anklet's +20,000 shows on its own line, outside Maneuver's 100k cap).
          boost = KEY_SUPP_SP.fetch(boost, boost)
          condition = c[:condition] || gate || {}
          { key_slug: slug, modifier: name, boost_type: boost, series: c[:series],
            value: value, scaling_kind: condition.present? ? "conditional_flat" : "static",
            value_unit: SUPP_BOOSTS.include?(c[:boost_type]) ? "flat" : "percent",
            condition: condition, applies_to: "element_allies", stacking: "additive",
            explicit: !c[:value].nil? }
        end
        effects.group_by { |e| [e[:boost_type], e[:scaling_kind]] }
               .map { |_, group| group.find { |e| e[:explicit] } || group.first }
               .each { |e| e.delete(:explicit) }
      end

      # The ≥280% Effect cell (Extremity/Sagacity/Supremacy …) → conditional key effects. The
      # generic "Skill:" prose has no values; the Effect column carries them + the boost_level gate.
      def self.boost_level_effects(slug, name, effect_text)
        return [] if effect_text.blank?

        GameplayNotesParser.inline_boosts(effect_text)
                           .uniq { |b| [b[:boost_type], b[:value]] } # tiered cells repeat a clause verbatim
                           .map do |b|
          { key_slug: slug, modifier: name, boost_type: b[:boost_type], series: b[:series],
            value: b[:value], scaling_kind: "conditional_flat",
            value_unit: SUPP_BOOSTS.include?(b[:boost_type]) ? "flat" : "percent",
            condition: { "type" => "boost_level", "gte" => 280 }, applies_to: "element_allies", stacking: "additive" }
        end
      end

      # Size-word clause (no explicit %) → the canonical SL-curve value (series pages quote SL20).
      def self.curve_value(clause)
        return nil unless clause[:size]

        curve = WeaponSkillDatum.canonical_curve(boost_type: clause[:boost_type], size: clause[:size],
                                                 formula_type: clause[:formula_type] || "flat")
        curve && (curve.sl20 || curve.sl15)
      end

      def self.persist(slug, effects, stats)
        WeaponSkillEffect.for_key(slug).delete_all # idempotent — re-derive from the wiki
        effects.each { |attrs| WeaponSkillEffect.create!(attrs) }
        stats[:keys] += 1
        stats[:effects] += effects.size
      end

      def self.fetch(wiki, page)
        wiki.fetch(page)
      rescue Granblue::Parsers::WikiError
        nil
      end

      private_class_method :clause_effects, :boost_level_effects, :curve_value, :persist, :fetch
    end
  end
end
