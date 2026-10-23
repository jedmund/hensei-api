# W6c: per-version descriptions

**Wave 2.** Depends on W3 (stored sources). Migration block `…15xxxx` (use `…1550xx`, so W6a and W6b keep the rest). Branch `pipeline/W6c-descriptions`. Issue label `pipeline:W6`.

## Goal

Each version carries its own tier text. The shared `Skill.description_en` is shared by name across weapons and tiers, and four writers overwrite it with no stamp. That's how Celestial tier I picked up tier II's E. ATK text. `Skill` stays the name and icon catalogue.

## Deliver

1. **Migration:** add `description_en` and `description_jp` (text) to `weapon_skill_versions`.
2. **Backfill** from stored sources, per tier. This can be a data migration that reads the store, or a task the migration calls; either way it's offline.
   - **Inline pages:** the tier's own wiki fields (`sN_desc`, `ensN_desc`, `sN_4s_desc` and the transcendence suffixes; see `WeaponParser#build_skill_entry` and `WeaponSkillDescriptionExtractor.full_description`).
   - **Series-template pages:** the expanded skill table, matching the row by name.
   - **Fallback:** where neither yields text, copy today's `Skill.description_*`, and report which versions fell back.
3. **`WeaponSkills::VersionText.for(version, locale)`:** the one accessor for a version's text (the version's own text, else the skill's).
4. **Switch readers to it:** the weapon blueprints (the API shows tier text), the extractor's `full_description` (coordinate with the W6b agent, who ports the extractor) and `backfill_weapon_skill_sizes`.
5. **Ship the column without changing the API's shape.** If any API response changes, say so in the PR.
6. **Tell the W7 agent** that the overlay's `description` op will write these columns.

## Owned files

- the migration(s)
- `lib/weapon_skills/version_text.rb`
- `app/models/weapon_skill_version.rb` (description methods only)
- the weapon blueprints' skill-description fields
- `lib/tasks/weapon_skill_data.rake` (`backfill_weapon_skill_sizes` only)
- specs

## Acceptance

- `granblue:skill_parity` passes unchanged.
- Celestial tier I and tier II texts differ, and tier I mentions no E. ATK (spec).
- A version's text no longer changes when another weapon sharing the skill is reparsed (spec).

## Notes from wave 1

- **Sources:** use `catalogue-20261015-sources` and read tier text from stored sources only, through `Granblue::Parsers::Wiki.offline { }` / `WeaponSkills::SourceStore::Database`.
- **The `description` op:** W7's overlay applies it as soon as the columns exist. It assumes they're named `description_en` / `description_jp`; tell the W7 agent if you name them differently.
