# frozen_string_literal: true

module WeaponSkills
  module Build
    module Rows
      # Port of ExpandedWeaponSkillImporter.apply_gameplay_notes / create_notes_effect: the
      # expanded page's "Gameplay Notes" carry the community-computed values the skill blurbs
      # omit (Voltage's per-weapon %, Cloud's per-specialty table). Returns effect attribute
      # hashes instead of writing them.
      module GameplayNotes
        # Families whose notes are already modeled canonically. "Grand Epic" is new here. Its
        # canonical effect is ex_atk_sp per Epic weapon (count_basis series:epic), but the notes
        # parser reads its section as plain "atk" per same weapon type: a second boost that
        # double-counts. No database row came from it today (its pages are inline, so a reparse
        # never expanded them), so skipping it keeps parity. See #546.
        CANONICAL_NOTES_FAMILIES = ["Staff Resonance", "Grand Epic"].freeze
        # The notes-owned scaling kinds: the description pass leaves these alone (its purge
        # spares them), so they survive it. A notes "static" row does not.
        KEPT_KINDS = %w[per_grid_count specialty_scaled].freeze

        # A pure key-determined page (every key option listed) is left to the key resolver:
        # the importer bails before persisting skills or notes. Mixed pages carry a key slot.
        KEY_PAGE = /granted power with (an?|a) (anklet|pendulum|teluma|chain)|empowered by a chosen/i
        KEY_SLOT = /granted power with (?:an? |a )?(anklet|pendulum|teluma)
                    |empowered by a chosen (pendulum|teluma)
                    |a (gate) to the summits|(?:locked|sealed) within (ultima)/xi

        module_function

        # expanded wikitext → { skill_name => { frame:, clauses: [...] } }; {} when the page's
        # notes don't apply (see KEY_PAGE).
        def parse(expanded)
          return {} if expanded.blank? || (expanded.match?(KEY_PAGE) && !expanded.match?(KEY_SLOT))

          Granblue::Parsers::GameplayNotesParser.parse(expanded)
        end

        # notes: the parsed notes for the version's weapon (see .parse). → [attributes]
        # Curation wins (#537): a boost type that is suppressed or already curated on the
        # version isn't generated. (The importer checks curated effect rows only; the
        # CurationView answers for data and effects together, as the description pass does.)
        def effects(version, notes, curation:)
          name = version.skill_name_en.to_s
          return [] if notes.blank? || CANONICAL_NOTES_FAMILIES.include?(name)

          info = notes[name] or return []
          skip = curation.curated_boost_types(version) | curation.suppressed(version)
          info[:clauses].filter_map do |clause|
            effect(name, info, clause) unless skip.include?(clause[:boost_type])
          end
        end

        # info: the section's { frame:, applies_to: }. Who the boost reaches comes from the notes
        # text ("Affects allies of any element"); a per-count boost depends on the grid count,
        # as the canonical per_grid_count rows do.
        def effect(name, info, clause)
          base = { modifier: name, boost_type: clause[:boost_type], series: info[:frame], value_unit: "percent",
                   applies_to: info[:applies_to] || "element_allies", stacking: "additive" }
          case clause[:scaling]
          when :per_count
            base.merge(scaling_kind: "per_grid_count", value: clause[:value], count_basis: "same_weapon_type",
                       total_cap: clause[:max], shared_cap_group: clause[:shared_cap], depends_on: ["grid_count"])
          when :per_specialty
            base.merge(scaling_kind: "specialty_scaled", condition: { "specialties" => clause[:by_specialty] })
          when :flat
            base.merge(scaling_kind: "static", value: clause[:value])
          end
        end
      end
    end
  end
end
