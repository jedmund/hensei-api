# W6b: row compiler

**Wave 2.** Depends on W0 (`BuildResult`) and W3 (stored expansions, for the gameplay notes). It can start against `BuildResult::Version` without waiting for W6a. Migration block `…15xxxx` (you shouldn't need one). Branch `pipeline/W6b-rows`. Issue label `pipeline:W6`.

## Goal

A pure function from a version to its generated rows:

```ruby
WeaponSkills::Build::Rows.call(version, text:, registry:, curation:, notes:)  # → [Row]
```

- `version` is a `BuildResult::Version` with the classification resolved through the overlay's overrides.
- `text` is the tier's description.
- `registry` is a read-only view of canonical data and effects plus the families (`WeaponSkillDatum.canonical`, `WeaponSkillEffect` canonical rows, `WeaponSkillFamily`).
- `curation` is the boost types that are curated or suppressed on this version.
- `notes` are the parsed Gameplay Notes clauses for the weapon.

No database writes, no network, no dependence on row order.

## What to port (copy, don't edit; W8 deletes the originals)

- **`Granblue::Extractors::WeaponSkillDescriptionExtractor`:** `apply`, `canonical_boost_types`, `family_curve`, `write_data`, `write_effect`, `sl_scaled?`, `backfill_family` (the classification part) and the `covered` logic.
  - Use `resolved_*` in `family_curve`; W1 fixes the original the same way.
  - The parser it calls, `Granblue::Parsers::WeaponSkillDescriptionParser`, is already pure. Call it; don't copy it.
- **`ExpandedWeaponSkillImporter.apply_gameplay_notes` / `create_notes_effect`:** with `Granblue::Parsers::GameplayNotesParser` (pure, call it), returning rows instead of writing.
- **Determinism:**
  - Every "pick one of several candidates" must have an explicit, total ordering. W0 found one: `WeaponSkillDatum.canonical_curve` broke ties by row order.
  - Audit `.find`, `.first`, `max_by` and `min_by` over relations or unordered collections.
- **Known case:** extracting Lovers-Death's Demise logs "Validation failed: Modifier has already been taken". Find out why and make the compiler produce one answer.

## Curation view

Today the extractor skips boost types that are covered by canonical rows, manual rows or `suppressed_boosts`. Keep that behaviour through a small `CurationView` interface (`curated_boost_types(version_identity)`, `suppressed(version_identity)`). For now it's backed by the database; W7's overlay backs it later. Agree the interface with the W7 agent.

## Measuring

Add `granblue:compare_rows [ids=] [series=]`. For each version, it compares `Rows.call` with today's generated version-linked rows (`manually_edited_at` nil) on boost type, condition and every value column. The description text comes from wherever the extractor reads it today (`full_description`: the weapon's `wiki_raw` `sN_desc`, falling back to `Skill.description_en`), so the comparison is like for like.

## Owned files

`lib/weapon_skills/build/rows*.rb`, `lib/weapon_skills/build/rows/**`, `lib/weapon_skills/build/curation_view.rb`, `lib/tasks/compare_rows.rake`, specs.

## Acceptance

- `compare_rows` over all versions: zero differences except the classified `parser` and `accept` cases.
- An order-independence spec (shuffled registry gives the same rows).
- Specs for a curve family, a fallback `canonical_curve` tie, a gameplay-notes Voltage weapon, a Celestial specialty table, and a suppressed boost type.
