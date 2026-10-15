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
