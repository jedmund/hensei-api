# W5: key-skill parity classification

**Status:** measurement pending on W3's stored sources (#541). Until a catalogue dump carries `weapon_sources` with the five key series pages, `granblue:key_skill_parity` aborts instead of reading the wiki.

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

## Known finding before measurement

The extractor never sets `total_cap` or `shared_cap_group`. Two anklet rows carry both, set by migrations (#434, #452):

| key | boost_type | total_cap | shared_cap_group |
|---|---|---|---|
| `anklet-ascendance` | `skill_dmg_cap` | 50 | `key_skill_cap` |
| `anklet-oblivion` | `na_dmg_cap` | 10 | `key_na_cap` |

A re-extraction drops both. The snapshot sees the `total_cap` loss. It doesn't see the `shared_cap_group` loss until the lead adds that column to the `keys` section (requested on #538). Proposed class: **curate**. Mark these rows curated (`manually_edited_at` via the curation overlay, W2's mechanism) so `persist` keeps them.

## Differences

_Filled in after the measurement run._

| key | difference | class | action |
|---|---|---|---|
