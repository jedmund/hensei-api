# frozen_string_literal: true

module WeaponSkills
  module Build
    module Rows
      # Port of ExpandedWeaponSkillImporter.apply_gameplay_notes / create_notes_effect: the
      # expanded page's "Gameplay Notes" carry the community-computed values the skill blurbs
      # omit (Voltage's per-weapon %, Cloud's per-specialty table). Returns effect attribute
      # hashes instead of writing them.
      module GameplayNotes
        # Families whose notes are already modeled canonically.
        CANONICAL_NOTES_FAMILIES = ["Staff Resonance"].freeze
        # The notes-owned scaling kinds: the description pass leaves these alone (its purge
        # spares them), so they survive it. A notes "static" row does not.
        KEPT_KINDS = %w[per_grid_count specialty_scaled].freeze

        module_function

        # expanded wikitext → { skill_name => { frame:, clauses: [...] } }
        def parse(expanded) = Granblue::Parsers::GameplayNotesParser.parse(expanded)

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
            effect(name, info[:frame], clause) unless skip.include?(clause[:boost_type])
          end
        end

        def effect(name, frame, clause)
          base = { modifier: name, boost_type: clause[:boost_type], series: frame, value_unit: "percent",
                   applies_to: "element_allies", stacking: "additive" }
          case clause[:scaling]
          when :per_count
            base.merge(scaling_kind: "per_grid_count", value: clause[:value], count_basis: "same_weapon_type",
                       total_cap: clause[:max], shared_cap_group: clause[:shared_cap])
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
