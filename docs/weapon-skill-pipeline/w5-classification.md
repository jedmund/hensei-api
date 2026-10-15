# W5: key-skill parity classification

**Status:** measured 2026-10-15 against `catalogue-20261015-sources` (offline, rolled back). **3 keys differ, all classified `parser`.** The diff is `w5_key_diff.json` (a release asset on `catalogue-20261015-sources`).

## How to measure

```sh
bin/setup-pipeline-db W5 <catalogue tag with weapon_sources>
export DATABASE_URL=postgres://localhost/hensei_pipeline_w5 CURATION_AUTO_EXPORT=0
bin/rails granblue:key_skill_parity OUT=data/weapon_skill_parity/w5_key_diff.json
```

The task runs `KeySkillExtractor` against `WeaponSkills::SourceStore::Database` inside a transaction, diffs the snapshot's `keys` section against `data/weapon_skill_parity/baseline.json`, and rolls back.

**Pages read** (kind `wiki_raw`, key = title, `weapon_id` NULL): `Dark Opus Weapons`, `Destroyer Weapons`, `Draconic Weapons`, `Draconic Weapons Provenance`, `Ultima Weapons`.

## Scope: what extraction can change

The baseline has 87 key effects on 45 of the 49 `weapon_keys`. `persist` skips the curated prefixes (`chain-`, `pendulum-`, `gauph-`, `teluma-`) wholesale, so extraction only rewrites keys outside them: the three Destroyer anklets (`anklet-ascendance`, `anklet-maximality`, `anklet-oblivion`, 12 rows). Parity for the other 42 keys rests on the prefix skip and curation, not on extraction.

Rows with `manually_edited_at` are now kept on every key (today only one, on `pendulum-alpha`).

## Run summary

`{curated_skipped: 16, effects: 7, keys: 3, no_value: 11, preserved: 2, unmatched_key: 1}`
- **All five pages were read from the store** (no `fetch_failed`). `Draconic Weapons Provenance` is a redirect to `Draconic_Weapons#Forging to Provenance` with no key tables of its own, so it adds nothing.
- **Ultima Weapons yields no key entries:** `SeriesKeyParser` finds no key tables on it. All gauph keys are under the curated `gauph-` prefix, so this changes nothing today.
- **`unmatched_key: 1` is Δ Pendulum:** the lookup is `lower(name_en) = ?` with Ruby's `downcase` ("δ pendulum"), and Postgres `lower('Δ')` doesn't fold the Greek capital under this database's collation. It's harmless because `pendulum-` is curated.

## Cap rows on the anklets (resolved by W2)

The extractor never sets `total_cap` or `shared_cap_group`. Two anklet rows carry both, set by migrations (#434, #452):

| key | boost_type | total_cap | shared_cap_group |
|---|---|---|---|
| `anklet-ascendance` | `skill_dmg_cap` | 50 | `key_skill_cap` |
| `anklet-oblivion` | `na_dmg_cap` | 10 | `key_na_cap` |

W2's curation (#553, now in `pipeline/integration`) marks both rows `manually_edited_at`. `persist` keeps them (`preserved: 2`), so they don't appear in the diff.

## Differences

| key | difference | class | action |
|---|---|---|---|
| `anklet-ascendance` | `elem_reduc` 30% (≥280 gate) missing | `parser` | see below |
| `anklet-maximality` | `elem_reduc` 30% (≥280 gate) missing | `parser` | see below |
| `anklet-oblivion` | `elem_reduc` 30% (≥280 gate) missing | `parser` | see below |

**Why it's missing:** all three anklets share the prose "…amplify superior elemental damage by 30%, and 30% reduced damage taken from superior element." `WeaponSkillDescriptionParser` returns the cap, supplement and `elem_amplify` clauses but no clause for "N% reduced damage taken from superior element". The `elem_reduc` rows in the database came from outside the extractor. Every other field of the re-derived rows matches the baseline.

**Action:**
- **Parser fix (W6, which owns the parser):** map "N% reduced damage taken from superior element" to `elem_reduc` with value N. This isn't specific to keys. A fix restores the three rows, and the anklet keys then reach zero differences.
- **Until then:** don't run `granblue:extract_key_skills` with writes. If it has to run sooner, curate the three `elem_reduc` rows (W2's mechanism) so `persist` keeps them.
