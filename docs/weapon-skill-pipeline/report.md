# Weapon-skill pipeline: report

Where the weapon-skill calculator stands, what the rewrite and the golden captures taught us, and where to pick up. Written 2026-10-17, when `pipeline/W9-goldens-3` was opened as a PR.

## Where we are

**Every captured panel matches.** The calculator is checked against 76 in-game panel references from 48 golden parties: 2,393 checks (panel lines, the enhancement header, and lines that must be absent). All of them pass. 18 further lines are marked open because they can't be checked yet (XZq7xW's missing account data, lines waiting on captures).

**Before and after the rewrite.** The same 76 references, scored with today's calculator against the production catalogue from just before the rewrite (`catalogue-20261015-prod`, no later data migrations):

| | Before the rewrite | Now |
|---|---|---|
| Checks passing | 2,200 of 2,393 (91.9%) | 2,393 of 2,393 (100%) |
| References matching every line | 22 of 76 | 76 of 76 |

The "before" column is generous: both columns run today's calculator code, so the code fixes from the same period count for the old data too. The old data missed most often on EX Might Sp. and EX Might, C.A. DMG Cap and Sp. C.A. Cap, C.B. and FC Amp., Charge Gain, C.A. Supp., the Arcarum DMG Cap line, and a Bonus DMG line the game doesn't show. Every Fire grid missed 7–9 lines.

**Coverage of the catalogue** (3,759 skill versions; details in [w9-golden-grids.md](w9-golden-grids.md#accuracy-and-coverage)):
- 86% have values: 72% from family templates, 8% hand-curated with a citation, 6% on a borrowed fallback curve (ATK Big/Massive/Medium and Armed confirmed in game; 26 Optimus stopgap rows still unverified).
- 14% (526) have no values. Most never reach the panel: main-hand procs, battle triggers, utility, defensive and status skills, key-slot placeholders, flat weapon-stat boosts. A keyword pass suggests roughly **50–80 real gaps** (about 2% of the catalogue), mostly event, collab and side-series weapons, and two Odious skills (Taboo Doomfire's Puncturing, Allowater's Guile).

**Estimate (not measured):** typical endgame grids (Optimus, Omega or Odious with Opus, Destroyer, Celestial, Ultima) should be exact on 95%+ of panel lines; grids leaning on event or collab weapons, 85–90%.

## What we did

1. **The pipeline rewrite (W0–W8).** Replaced the import writers with one deterministic build: stored wiki sources (fetched once, never parsed live) → a pure build → a committed curation overlay → one read-time precedence rule. Parity first: the build reproduced the shipped data exactly (`granblue:skill_parity` against `data/weapon_skill_parity/baseline.json`) before anything changed. Rerunning the build gives the same result, so curation can't be lost to a reparse again (the July curation loss).
2. **Goldens in CI (W4).** Each golden party is a self-contained fixture (`spec/fixtures/goldens/`) carrying the catalogue rows it needs, so CI checks every reference on every change and the saved party can be deleted afterwards.
3. **Correctness (W10) and recaptures (W9).** Captured in-game panels, compared, fixed the calculator or curation with a citation, re-measured. Three rounds (#592, #594, and `pipeline/W9-goldens-3`).

**This last round** (`pipeline/W9-goldens-3`):
- **Arcarum.** Sephira Maxi's Arcarum boost is its own DMG Cap (Arc) line, capped at 20 (was +15 on DMG Cap). Sephira Tek's Critical and Soul's HP apply only in Arcarum (were always on). Salire adds HP DMG 40 in Arcarum.
- **Bonus DMG on single or triple attacks only** (Sol Remnant's Astral Blow II) stays off the panel: routed to its own key and registered as a hidden boost type.
- **The 1% HP point** now reads like the in-game calculator: 1 HP for skills that grow as HP falls, 0 for HP-scaled supplements, the true 1% for Persistence.
- **AX Enmity +1** uses the panel's values at 50% and 25% instead of the wiki's rounded table.
- **Confirmed with no change needed:** the EX ATK Massive fallback (23 versions), Firestorm's Enmity (an Optimus stopgap), Vermillion Covenant as a sub, Ridge's Surge, Gun Voltage II, Salire's N.A. DMG Cap, and the Taboo aura below its cap (Od 302.5% at 15 exorcision levels, linear as modelled).

**Runs on deploy:** data migrations `20261017050000` (DMG Cap (Arc) display cap 20), `20261017070000` (HP DMG display cap 40) and `20261017090000` (hidden single- and triple-attack Bonus DMG keys); the curation sync, including `remove_row` ops for the old Sephira Maxi `dmg_cap` rows and the Blow family's `bonus_elem_dmg` row.

## What we learned

### How the in-game panel works

- **Display.** Values of 100 or more drop their decimals (Might 160.6 shows 160); smaller values show two decimals. Some whole numbers round instead (Garrison 276.8 shows 277). Orange means the line is at its *display* cap (`display_cap`), not just above the grid cap.
- **The enhancement header** (Optimus / Omega / Od) counts the support summon. A party imported without its friend summon reads half.
- **Critical isn't part of Estimated DMG** (Sephira Tek adds Critical 30 and Estimated DMG doesn't move). **DMG Cap (Arc)** changes only Estimated DMG to the weak element.
- **The HP slider's lowest point is labelled 1% but works as 1 HP** for Enmity, Garrison, AX Enmity and Stamina and HP-linear skills; HP-scaled supplements read their 0% value; Persistence reads the true 1%. The slider can't be set to 2–4%.
- **Some real effects never show:** main-hand-only skills when not in the main hand; position-targeted skills ("for an ally in third position") on the MC's panel; Undersky's Whispers (main hand only, visible only in Estimated DMG, so it's `panel_hidden` and listed under Hidden stats); bonus DMG on single or triple attacks only; β Pendulum's skill hit rate.
- **Main-hand "massive critical" skills are a fixed 30** and don't level (Bang! at SL1 = SL15). Main-hand "multiattack rate" skills are a fixed DA 20 / TA 10.
- **The Taboo aura is linear** across exorcision levels between its base and its cap.
- **The wiki's tables are rounded.** Where the panel disagrees by a hundredth (AX Enmity), the panel wins.

### How to capture well

- **Compare against a base:** the same party without the test weapon, nothing else changed. One weapon per capture unless they sit on different lines.
- **Import right before capturing**, and check the friend summon on the team page.
- **Arcarum, World and Militis weapons need two captures**: the calculator's Arcarum switch off, then on.
- **For a full-HP capture, paste the deck JSON**: it has exact values (230.5 where the panel shows 230).
- **HP sweeps:** 100/75/50/25/10/5/1%. 10% and 5% are the exact low points; 1% is the 1 HP point.
- **Stash weapons go in private parties**, but the importer reads only the public API, so a private party returns 404. Make it unlisted for the import, then private again or delete it once the fixture is exported.
- **List what the game doesn't show in `absent`.** The validator checks only listed lines; an extra line we produce goes unnoticed otherwise (the Sol Remnant Bonus DMG line hid in three older goldens).
- **Show the diff before digging in.** The capturer knows the grid; a mismatch is often a capture detail, not a bug.

### What went wrong along the way

- **I assumed Arcarum didn't need its own capture.** It did: three of the four Arcarum captures found real bugs.
- **Claims about missing values came from bad queries** (Kiss of The Devil's EX ATK, Ridge's Surge). Check the resolved rows, not one table.
- **A parser fix can leak** an unregistered key onto the panel as a raw line. Register new keys as boost types (hidden if the game doesn't show them).
- **An earlier 1% reading (HP 0.1–0.25%) was wrong** because it assumed rounding where the panel truncates.

## Working on it

- **Databases:** `bin/setup-pipeline-db NAME [TAG]` creates `hensei_pipeline_<name>` from a catalogue release. Then `export DATABASE_URL=postgres://localhost/hensei_pipeline_<name> CURATION_AUTO_EXPORT=0`. Unset `DATABASE_URL` (and any proxy variables) for rspec and `git push`. Never point anything at a remote database.
- **A capture, end to end:**
  1. `bin/rails granblue:import_golden_party shortcode=X`
  2. write `data/panel_references/X.json` (and `X_hpNN`, `X_arc`, `X_..._noarc` variants);
  3. `bin/rails granblue:validate_panel party=X` checks the base reference; `spec/requests/goldens_spec.rb` checks all of them;
  4. fix the calculator, or curation in `data/weapon_skill_curation/*.json` with a citation, then `granblue:sync_weapon_skill_curation`;
  5. `bin/rails granblue:export_golden_fixture shortcode=X` (always pass the shortcode: without it the task re-exports only existing fixtures), then `git checkout -- data/weapon_skill_curation/proven.json`;
  6. a boost-type change needs a `db/data` migration plus `granblue:export_boost_registry`; it changes every fixture, so re-export them all;
  7. before a PR: the full suite, rubocop on changed files, `granblue:skill_parity`, `granblue:weapon_skill_curation_drift`.
- **Re-measuring the before/after score:** restore `catalogue-20261015-prod` without migrating (a copy of `bin/setup-pipeline-db` with `db:migrate:with_data` removed), let it load the golden fixtures, and run `PanelValidator` over every reference whose party has a fixture, counting non-skipped lines, enhancement frames and `absent` keys.

## Where to pick up

In order of value:

1. **Audit the 526 versions without values.** Classify each as "not a panel boost" or "gap", then curate the gaps from the cached wiki sources. Start with the Odious pair (Taboo Doomfire's Puncturing, Allowater's Guile), then the common-weapon ones (Bonds of Blue, Game Changer, Titan's Aegis, Hero's Stature, Oracle's Allegiance, Possessive Passion, Zero to Hero). This turns the coverage estimate into a measurement and needs no captures.
2. **Captures**, ranked in [w9-golden-grids.md](w9-golden-grids.md#next-captures):
   - #17 Water: the Taboo aura's low end (0★ Odious weapons at exorcision 1, Nihuyvintae 5★);
   - the Arcarum switch captures: Sephira Soul, Worldforging Moros (C.A. Amp. (Arc)), Worldscathing Leon or Worldvexing Angelos (N.A. Amp. (Arc)), Salire below full HP;
   - EX HP Big and Medium at SL15–20 (21 rows on a borrowed curve, right at SL1);
   - the remaining stopgaps (True Purity Sunblade, then the "Still to find" weapons);
   - Armed checks, Edem, Proven awakenings, Malus, Hollowsky covenants;
   - #2 HoEE8b (lets the parity baseline be deleted), #8–#13, XZq7xW's re-import.
3. **An Estimated DMG model.** Three open items can only be checked through Estimated DMG, not the panel: Undersky's Whispers (11.13 at SL20 if it's a separate multiplier; we carry the stopgap 13.5), Salire's low-HP ATK in Arcarum, and Critical. A model of Estimated DMG would also let every capture check one more number.
4. **Open questions:** see [w9-golden-grids.md](w9-golden-grids.md#open-questions): `reduction_effect_value` on Odious weapons, Undersky's value, Malus below SL20, Salire's low-HP ATK.
5. **Waiting on the user (web):** the Japanese strings and the calculator tooltip accessibility fix.
