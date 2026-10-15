# W6a classification: structure compiler vs today's database

**Input:** `bin/rails granblue:compare_structure` on `catalogue-20261015-sources` (database `hensei_pipeline_w6a`). It runs `WeaponSkills::Build::Structure.call` on every weapon with a stored page or skills (1,866 weapons, 3,755 versions), applies the overlay's structural ops (`add_version`, `remove_version`, `gate`) and compares the result with the database by version identity `(weapon, position, ordinal)`.

**Compared fields:**
- skill name;
- gate (`unlock_level`, `min_uncap`, `transcendence_stage`);
- derived `skill_modifier`, `skill_series`, `skill_size`, `multiplier_frame`;
- icon, `main_hand_only` and `mc_only`.

**Where the details are:**
- **Every difference:** `compare_structure_last.json` (a release asset on `catalogue-20261015-sources`).
- **Each class and its citation:** `data/weapon_skill_parity/compare_structure_classifications.json`, keyed `weapon|position|ordinal|skill|field`.

The task fails on any difference that isn't classified.

## Result

| Class | Differences | Meaning |
|---|---|---|
| `backfill` | 146 | `skill_modifier`/`skill_size` blank in the compiler's output; the row compiler's family backfill (`Rows::Classification.backfill`) gives the database value. Checked per version. |
| `override` | 56 | Derived column on a version with a `modifier_override`/`series_override`/`size_override`; the overlay decides the resolved value. |
| `accept` | 121 | Below. |
| `parser` | 4 | W2's parser cases P1 and P6: tiers new on the wiki, now gated from the template. |
| `curate` | 32 | 16 versions; W2 curated them (PR #553). |
| `open` | 7 | One version: two catalogue weapons share a granblue_id. |
| unknown | 0 | |

**Overlay ops:** the output already satisfies all 95 structural ops in `data/weapon_skill_curation/*.json` (85 `gate`, 10 `add_version`), which `compare_structure_last.json` (a release asset on `catalogue-20261015-sources`) lists as `redundant_ops`. They can be retired once W8 switches the build over; until then they're harmless.

## What the compiler does beyond a straight port

Each of these is cited in the code (`lib/weapon_skills/build/structure*.rb`).

1. **Template level defaults** (`Structure::Wikitext.merge_template`). Today's merge skipped every `{{{…}}}` template line.
   - `sN_lvl={{{sN_lvl|230}}}` applies when the page has no `sN_lvl`. This is P2, Illustrious.
   - `sN_4s_x={{{sN_4s_x|{{{sN_u1_x|}}}}}}` moves a page's `u1` tier onto the template's `4s` fields, so the literal `s4_4s_lvl=250` reaches it. This is P1: Dos Colmillos II, Galactic Halo II, 250/5/5.
   - `#ifeq`/`#if` levels are evaluated: Epic `s2_lvl` from `epic_release_date` (P2) and Exo `s1_4s_lvl={{#if:{{{5star_date|}}}|200}}` (P6). When the condition is false, today's literal stays, and the level parse reads it as 0. That keeps the later Epics (All-Might Spear, Hermanubis) at today's `unlock_level` 0.
2. **Garbled tiers fill in from the template** (`Structure.filled_tier`).
   - Today's repair appended the expansion's skills after the last slot and dropped the garbled tiers they replaced, losing the gates.
   - The compiler evaluates the dropped tier's whole name field with a small wikitext evaluator (`Structure::Evaluator`: parameters, `#vardefine`/`#var`, `#if`, `#ifeq`, `#switch`), else matches it as a wildcard pattern.
   - The appended version keeps the tier's gate. This gives:
     - New World Majesty: 120/4/0 at position 4 (P3);
     - Coda Vita/Incursio/Rapidus: 200/5/0 (data migration 20261015120001);
     - True Xeno Supremacy: 200/5/0 (20261015140001);
     - Revans Zenith/Striking: 120/4/0;
     - Astral second skills: 120/4/0;
     - Sephirath II: 150/4/0.
3. **Key-determined pages** (`page_kind: key_determined`). Today's repair never ran on them: its `KEY_SLOT` had a `/x` flag that dropped the spaces, so it never matched.
   - Now the expansion's base rows (outside the key slots) take the place of the garbled tier they render. They keep its slot, gate and icon, as data migration 20261015100001 did by hand for the Draconic first skills.
   - Nothing is appended, so key options never become versions.
   - `KEY_SLOT` is rewritten with escaped spaces, and every phrase has a spec.
4. **Tier text fallback.** A tier with no text of its own reads the expanded skill's text, which is what `Skill#description_en`, shared by name, held. This is how the Ultima Rubell skills get size `big`.
5. **Mk II expansions.** A Mk II page that only transcludes its Mk I (`{{:Concordia|…}}`) uses the Mk I's stored expansion. No Mk II expansion is stored.
6. **`{{About}}` hatnotes.** A page that starts with `{{About|…}}` but has its own `{{Weapon…}}` block is read as is. `WeaponParser#skill_source_text` followed the hatnote to a missing "<name> (Weapon)" page, so 27 pages never parsed. The database kept whatever an older parser had written for them; all but the 8 in the accepted table below still match.
7. **Tie order.** Tiers with the same unlock level sort by suffix (base, 4s, 5s…, u1…). The old `sort_by` left ties to the sort algorithm.
8. **The parser comes from the stored `page_kind`**, never from the text.

`skill_series` is the extractor's final value: the frame of the first clause `WeaponSkillDescriptionParser.parse` finds ("ex" when that clause has no frame), else `series_for(text, name)`. The text is `Rows::Description.text`, as agreed with W6b.

`scales_with_skill_level` is left nil. It needs the family registry, so W8 sets it.

## Accepted differences (W6a's own)

| Rows | Weapons | Difference | Evidence |
|---|---|---|---|
| 12 missing | Revans Mk I and Mk II (×6 each) | `}}} Enforcement` at 0\|0 not produced | Junk name from an unexpanded `Template:Weapon/Common/RevansII` `s1_name` line. The version is inert: `modifier_override: none`, no rows (data migration 20261015100001). The compiler drops template-garbled names, as `WeaponParser#persist_single_skill` does. The overlay's override entries for them go unmatched. |
| 12 gate | Revans Mk II ×6 | third skill nil/3/0 → 120/4/0 | The Mk II page transcludes the Mk I, so its skills are the Mk I's (20261015100001). `Template:Weapon/Common/RevansII` `s2_lvl=120`. The Mk I already has 120/4/0 through its `revans.json` gate op; the Mk II copies were made before that op existed. |
| 8 size | Plume of Suparna, Eden ×2, Advocatus Diaboli, Edem ×2, Ouroboros, Wilhelm | size follows the description | `{{About}}`-hatnote pages the old parser couldn't read (item 6). Stored sizes predate today's parser; the new ones follow `WeaponParser#build_skill_entry` (description size word, `big_ii` for a "II" Big). |
| 2 | Twinpain-Wolf Gun | position 3 "Papillon Flamboyant" → "Gun Voltage II"; Gun Voltage II at 5 missing | "Papillon Flamboyant" is the page's `ougi_name`. An old import of the expansion's charge-attack table left it behind; `parse_skills` now reads only the weapon-skills table. It has no rows and no curation. Gun Voltage II moves from position 5 to 3, and its one generated effect moves with it (a parity key change for W8). |
| 5 gate | World ×5 (Sephirath II) | `unlock_level` nil → 150 | `Template:Weapon/Common/World` `s2_4s_lvl=150`. The `world.json` op (July recovery) sets only `min_uncap` 4, which is the same tier. |
| 3 | Yggdrasil's Bough (Astral Arts, Astral Arts II) | `Arts` link and size dropped | W2, w2-classification.md "From W6a": a false join, like Architect Battle Arts. |

**W2 rows:**
- **`accept`:** 81 differences, by row number in `w2-classification.md`: the Excelsior/Crux size drops, the false family links and the new tiers.
- **`parser`:** the 4 P1/P6 rows. The compiler now gives them the expected gates: Dos Colmillos II and Galactic Halo II 250/5/5; both Solaris's Supremacy: Decimation 200/5/0.

## Curated (W2, PR #553)

16 versions whose family and size came from a retired derivation:
- 6 Sovereign/unworldly;
- 8 Glacial/True Glacial Supremacy (massive);
- 2 Glacial Supremacy: Decimation (massive).

**Why nothing derives them:** `WeaponSkillParser` rejects the prefix ("Glacial", "Verglas"…) because it isn't a known aura. The versions are created by the expansion, so the importer never set a family.

**Why they matter:** the canonical rows are keyed by size, so without the family the calculator would lose them. W2 added `modifier_override` + `size_override` with today's values. Once that syncs, these show as `override`.

## Open

- **Ray of Zhuque Pontus / Regus share granblue_id `1040906600`.**
  - `weapon_skills` is keyed by granblue_id, so the build can hold only one weapon's skills. Today's rows are Pontus's.
  - Compiling Regus gives "Fire's Aegis" at position 1, against Pontus's "Wings of Divinity" (7 field differences).
  - The catalogue needs a decision (the lead). Until then the build must skip one of the two weapons, or key on the weapon row.
- **Expansions not stored:** the six Revans Mk II pages have none of their own; the compiler uses the Mk I's (item 5). W3 could store them.
