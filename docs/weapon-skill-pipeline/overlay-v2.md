# Curation overlay v2

The overlay is the only place weapon-skill corrections live. The build writes generated rows; the overlay is applied on top. Rebuilding can't erase it, because the build never writes curated rows.

`WeaponSkills::OverlaySchema.validate(doc)` checks the format; `spec/lib/weapon_skills/overlay_schema_spec.rb` pins it. W7 implements the applier.

## Files

- `data/weapon_skill_curation/<series-slug>.json`: curation for weapons in that series. Weapons with no series go in `_none.json`.
- `data/weapon_skill_curation/_canonical.json`: canonical rows (`weapon_skill_version_id` nil), including key-scoped effects (`key_slug`).
- `data/weapon_skill_curation/pending/<series-slug>.json`: fragments written before the applier supports them (W2). Same shape. W7 folds them into the series files.

Today's single `data/weapon_skill_curation.json` is v1. W7 splits it into the v2 layout and keeps reading v1 until the split lands.

Each file:

```json
{
  "format": 2,
  "versions": [ … ],
  "effects":  [ … ],
  "data":     [ … ],
  "ops":      [ … ]
}
```

Within a file, entries are sorted by weapon id, then skill, then ordinal, so diffs stay small. The same identity in two files is an error.

## Version references

Every weapon-specific entry names its version as in v1:

| Field | Meaning |
|---|---|
| `weapon` | weapon `granblue_id` (string) |
| `skill` | the skill's English name |
| `ordinal` | the version's ordinal within its slot (usually 0) |

Canonical entries have no `weapon`, `skill` or `ordinal`.

## `versions`: overrides (unchanged from v1)

`modifier_override` (`"none"` pins "no family"), `series_override`, `size_override` and `suppressed_boosts` (`["*"]` suppresses all extraction), plus `edited_at`.

## `effects` and `data`: curated rows (unchanged from v1)

These are the table columns (`CurationSnapshot::EFFECT_COLUMNS` / `DATUM_COLUMNS`) plus the version reference and `edited_at`. Identities:
- **effect:** version, `modifier`, `boost_type`, `key_slug`, `condition`;
- **datum:** version, `modifier`, `boost_type`, `series`, `size`, `formula_type`.

## `ops`: structural changes (new)

Every op has `op`, the version reference, `reason` (a citation: a gbf.wiki page and section, or a golden capture) and `edited_at`.

| op | Extra fields | Effect |
|---|---|---|
| `add_version` | `position`, `skill_jp`?, `description_en`?, `description_jp`?, `unlock_level`?, `min_uncap`, `transcendence_stage`? | Creates the slot and version when the build doesn't produce them (e.g. the fifth-slot Majesty skills). |
| `remove_version` | — | Drops a version the build produces but the game doesn't have. |
| `gate` | `unlock_level`?, `min_uncap`?, `transcendence_stage`? (at least one) | Sets the unlock requirements. Replaces `db/data/manifests/skill_version_gates.json`. |
| `description` | `description_en`? and/or `description_jp`? | Sets the version's text (after W6c), replacing parsed text. |

## Order of application

1. The build writes generated slots, versions and rows.
2. `remove_version`, then `add_version`.
3. `gate` and `description`.
4. Version overrides (`modifier_override`, `series_override`, `size_override`, `suppressed_boosts`). Suppression deletes generated rows of suppressed types.
5. Curated rows (create, or update when the snapshot's `edited_at` is newer).

## Precedence at read time

Per `(version, boost_type)`:
1. a curated row;
2. if suppressed, nothing;
3. the family default;
4. the generated row.

Data already resolves this way; effects move to it in W10. Until then, effects keep "linked beats canonical".

## Stamps

`edited_at` is ISO 8601 UTC. When a row exists in both places, the newer of the database stamp and the snapshot stamp wins, as in v1. That lets an admin edit made on prod survive until it's exported.
