# W6a: structure compiler

**Wave 2.** Depends on W3 (stored sources) being on `pipeline/integration`. Migration block `…15xxxx` (you shouldn't need one). Branch `pipeline/W6a-structure`. Issue label `pipeline:W6`.

## Goal

A pure function from stored sources to a weapon's slots and versions:

```ruby
WeaponSkills::Build::Structure.call(weapon, store:)  # → [slots, versions, warnings]
```

It's deterministic, makes no network or database writes, and doesn't depend on row order. W8 wires it into the build. The old writers keep working until then.

## What to port (copy, don't edit; W8 deletes the originals)

- **Inline pages** (`page_kind: inline`, the page has its own `sN_*` fields): `Granblue::Parsers::WeaponParser`
  - `parse_string`, `parse`, `extract_weapon_skills`, `discover_skill_versions`, `tier_for`, `build_skill_entry`, `resolve_ifeq_name`, `size_from_description`, `main_hand_only_description?`;
  - the source-text follow-ups (`skill_source_text`, `fetch_template`), which now read transclusions and templates from the store.
- **Series-template pages** (`page_kind: series_template`): `Granblue::Extractors::ExpandedWeaponSkillImporter.parse_skills` over the stored `expanded` source, plus the KEY_SLOT and alternate-skill rules, so key options never become versions.
- **Key-determined pages:** base skills only, as `repair_weapon` does today.
- **Choosing the parser:** by `page_kind`. Never by sniffing the text; the `s1_desc=` vs `|jps1_desc=` bug is why.

## Output

`WeaponSkills::BuildResult::Version` fields:
- identity `(weapon, position, ordinal)`;
- names (EN and JP), **the tier's own description text** (EN and JP; W6c stores it);
- `unlock_level`, `min_uncap`, `transcendence_stage`;
- derived `skill_modifier`, `skill_series`, `skill_size`, `multiplier_frame`;
- icon and flags.

Overrides are not your concern; they live in the overlay.

## Measuring

Add `granblue:compare_structure [ids=] [series=]`. It compares `Structure.call` for every weapon with today's database: the version identity set, names, gates, the derived classification and the icon. Report per weapon.
- **Expected differences:** the `parser` rows in `docs/weapon-skill-pipeline/w2-classification.md`, which your compiler should fix, and the `accept` rows.
- **Everything else** is a bug in the port, or a case to raise with the W2 agent or the lead.

## Owned files

`lib/weapon_skills/build/structure*.rb`, `lib/weapon_skills/build/structure/**`, `lib/tasks/compare_structure.rake`, specs.

Read-only: the old parser and importer files.

## Acceptance

- `compare_structure` over all weapons: zero differences outside the classified `parser` and `accept` cases.
- **Specs:**
  - one per page kind;
  - a Celestial page (template routing);
  - a weapon whose JP line contains `s1_desc=`;
  - Proven (the Armed slot);
  - a Dark Opus key page;
  - order independence (shuffle the inputs and get the same output).
- A WebMock (or equivalent) spec shows no HTTP.

## Notes from wave 1

- **From W2:** its `parser` cases P1–P3 are structure work for you: gates, template defaults, and New World's injected third skill. Details are in `docs/weapon-skill-pipeline/w2-classification.md` once W2's PR lands; ask W2 directly before that.
- **From W6b:** set `skill_series` on each `Version` the way the extractor does today, `series_override || WeaponSkillDescriptionParser.series_for(text, name)`. Row coverage depends on it, because the extractor re-derives the series before it works out which boost types are covered. Agree the exact field semantics with W6b.
- **From W3:**
  - `ExpandedWeaponSkillImporter::KEY_SLOT` is broken. Its `/x` flag drops the spaces in phrases like "empowered by a chosen pendulum", so they never match. Write your port's pattern without `/x`, or with escaped spaces, and spec every phrase.
  - Use `catalogue-20261015-sources` and read every page through `Granblue::Parsers::Wiki.offline { }` / `WeaponSkills::SourceStore::Database`.
- **New on 2026-10-15:** W3's offline full reparse (`full_reparse_offline_2026-10-15.json`, a release asset on `catalogue-20261015-sources`) reproduces W2's 103 differences plus 4 from wiki edits made that day (Daudaskot II gate, Blazing Chain III, two Exo Decimations). W2 is classifying the 4.
- **Curation now lives in W7's per-series files** (`data/weapon_skill_curation/*.json`), including `gate` and `add_version` ops. Your structure output plus the overlay must reproduce today's gates and slots.
