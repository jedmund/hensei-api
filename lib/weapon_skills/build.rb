# frozen_string_literal: true

module WeaponSkills
  # The weapon-skill build: a weapon's stored sources and the curation overlay in, the
  # weapon's slots, versions and generated rows out (docs/weapon-skill-pipeline/briefs/W8.md).
  #
  #   context = Build.context                   # load the overlay, registry and store once
  #   result  = Build.for(weapon, context:)     # → BuildResult (pure: no writes, no network)
  #   report  = Build::Writer.call(result, context:)
  #
  # Steps per weapon:
  #   1. Structure.call: slots and versions from the stored page.
  #   2. The overlay's structural ops: remove_version, add_version, gate, description.
  #   3. Per version: the description text the row compiler reads, the overlay's overrides
  #      resolved, then Rows.compile (family backfill, description rows, gameplay notes).
  #   4. Each version is written with its derived classification (overrides stay in the
  #      overlay's columns) and scales_with_skill_level from its resolved family.
  module Build
    # Bump when compiler output changes, so every weapon's fingerprint goes stale.
    VERSION = 1

    Parser = Granblue::Parsers::WeaponSkillDescriptionParser

    # What a build reads besides the weapon, loaded once per run.
    Context = Struct.new(:store, :overlay, :view, :registry, :ops, :overrides, keyword_init: true) do
      def ops_for(weapon_granblue_id) = ops.fetch(weapon_granblue_id.to_s, [])

      # The overlay's version entry for [weapon, skill name, ordinal], or {}.
      def override_for(version)
        overrides.fetch([version.weapon_granblue_id.to_s, version.skill_name_en.to_s, version.ordinal.to_i], {})
      end
    end

    module_function

    def context(store: SourceStore::Database.new, overlay: Granblue::CurationSnapshot.load,
                registry: Rows::Registry.from_database)
      Context.new(
        store: store, overlay: overlay, view: Granblue::CurationSnapshot::View.new(overlay), registry: registry,
        ops: overlay.entries("ops").group_by { |op| op["weapon"].to_s },
        overrides: overlay.entries("versions").to_h { |e| [[e["weapon"].to_s, e["skill"].to_s, e["ordinal"].to_i], e] }
      )
    end

    # weapon: a Weapon (granblue_id, wiki_en, name_en). → BuildResult, validated.
    def for(weapon, context:)
      slots, versions, warnings = Granblue::Parsers::Wiki.offline(store: context.store) do
        Structure.call(weapon, store: context.store)
      end
      versions = StructuralOps.apply(weapon.granblue_id, versions, context.ops_for(weapon.granblue_id))
      wiki_raw = stored_body(context.store, "wiki_raw", weapon.wiki_en).to_s
      notes = notes_for(context.store, weapon)

      built = versions.sort_by(&:identity).map do |version|
        compile_version(version, wiki_raw: wiki_raw, notes: notes, context: context)
      end
      rows = built.flat_map { |b| b[:rows] }
      warnings += built.flat_map { |b| b[:warnings] }
      version_slots = built.map do |b|
        BuildResult::Slot.new(weapon_granblue_id: weapon.granblue_id, position: b[:version].position)
      end
      slots = (slots + version_slots).uniq(&:identity).sort_by(&:identity)

      BuildResult.new(weapon_granblue_id: weapon.granblue_id, slots: slots, versions: built.map { |b| b[:version] },
                      rows: rows, warnings: warnings).validate!
    end

    # One version: its rows, compiled against the resolved classification, and the version
    # to write, which keeps the derived classification where the overlay overrides it.
    def compile_version(version, wiki_raw:, notes:, context:)
      override = context.override_for(version)
      text = Rows::Description.text(wiki_raw: wiki_raw, position: version.position, name: version.skill_name_en,
                                    fallback: version.description_en)
      derived_series = text.present? ? Parser.series_for(text, version.skill_name_en) : version.skill_series
      resolved = with(version,
                      skill_modifier: resolved_modifier(override, version.skill_modifier),
                      skill_series: override["series_override"].presence || derived_series,
                      skill_size: override["size_override"].presence || version.skill_size)

      result = Rows.compile(resolved, text: text, registry: context.registry, curation: context.view, notes: notes)
      filled = result.version
      written = with(filled,
                     skill_modifier: override["modifier_override"].present? ? version.skill_modifier : filled.skill_modifier,
                     skill_series: derived_series,
                     skill_size: override["size_override"].present? ? version.skill_size : filled.skill_size,
                     scales_with_skill_level: scales?(filled, context.registry))
      { version: written, rows: result.rows, warnings: result.warnings }
    end

    # WeaponSkillVersion#resolved_modifier, from the overlay instead of the row.
    def resolved_modifier(override, derived)
      pinned = override["modifier_override"]
      return nil if pinned == "none"

      pinned.presence || derived
    end

    # A version scales with skill level when its resolved family has canonical curve data
    # or a weapon_skill_curve base effect (WeaponParser#scales_with_skill_level?).
    def scales?(version, registry)
      modifier = version.skill_modifier
      return false if modifier.blank?

      registry.for_skill(modifier: modifier, series: version.skill_series, size: version.skill_size).any? ||
        registry.curve_effect?(modifier)
    end

    # Gameplay Notes from the weapon's stored expansion, for every weapon that has one.
    def notes_for(store, weapon)
      expanded = stored_body(store, "expanded", weapon.wiki_en)
      expanded && Rows::GameplayNotes.parse(expanded)
    end

    def stored_body(store, kind, key)
      return nil if key.blank?

      store.fetch(kind, key).body
    rescue SourceStore::SourceMissing
      nil
    end

    def with(version, **changes)
      copy = version.dup
      changes.each { |k, v| copy[k] = v }
      copy
    end
  end
end
