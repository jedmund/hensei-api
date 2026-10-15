# frozen_string_literal: true

module WeaponSkills
  module Build
    module Rows
      # The classification part of the extractor's backfill_family: a version with no
      # family gets one from its skill name when that name resolves to a family with
      # canonical rows ("Water's Majesty" → Majesty), so the family's own SL curves resolve
      # instead of the family-blind size fallback. Returns a new Version; never mutates.
      module Classification
        NameParser = Granblue::Parsers::WeaponSkillParser

        module_function

        # pinned: the overlay sets this version's modifier (including "none"), so the name
        # must not supply one.
        def backfill(version, parsed, registry, pinned: false)
          return version if pinned || version.skill_modifier.present?

          # Full-name-keyed families first: curated canonical rows for weapon-unique skills
          # use the whole skill name as the modifier ("Pillar-Smasher's Conviction").
          full = version.skill_name_en.to_s
          return with(version, skill_modifier: full) if full.present? && registry.canonical_family?(full)

          name = NameParser.parse(full)
          family = name[:modifier]
          return version unless family && NameParser::KNOWN_MODIFIERS.include?(family)
          # effect-only families count too (Rubell: conditional canonical effects, no curve)
          return version unless registry.canonical_family?(family)

          updates = { skill_modifier: family }
          size = name[:size] || parsed[:clauses].filter_map { |c| c[:size] }.first
          updates[:skill_size] = size if version.skill_size.blank? && size
          with(version, **updates)
        end

        def with(version, **changes)
          copy = version.dup
          changes.each { |k, v| copy[k] = v }
          copy
        end
      end
    end
  end
end
