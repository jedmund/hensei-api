# W9: golden grids to build

Golden parties are in-game captures of the weapon panel ("Weapon Skill Boosts"). CI checks the calculator against them. This doc lists what's left to capture, how to build each party, and what's already done.

## How to help

1. Take the next unchecked item in **[Next captures](#next-captures)** and open its recipe.
2. Build the party, following [Before you capture](#before-you-capture).
3. Send me the party link and the screenshots. I write the reference and fix whatever doesn't match.

A capture with a test weapon is always compared against its base: the same party without the test weapon (or with the original main hand). Change nothing else between the two.

Goldens are self-contained fixtures (`spec/fixtures/goldens/`), so a saved party can be deleted once its fixture is exported. Keep the parties listed under [Base grids](#base-grids) while captures still build on them.

## Accuracy and coverage

As of 2026-10-16, after #594 (Build::VERSION 10 plus the W9 curation).

**Accuracy on captured grids (measured):** 39 golden parties, 56 references, 1,438 panel lines. 1,416 match exactly and are checked in CI on every change. 22 lines (1.5%) are open, all for known reasons: the HP slider's 1% point, XZq7xW's missing account data, and lines waiting on captures. None is an unexplained mismatch.

**Coverage of the catalogue (measured):**

| Skill versions (3,759) | Count | Share | Reliability |
|---|---|---|---|
| Have values | 3,225 | 86% | |
| from a family template | 2,720 | 72% | high: wiki tables, checked by goldens for the common families |
| hand-curated, with a citation | 285 | 8% | high |
| borrowed fallback curve | 232 | 6% | ATK Big, Armed and ATK Medium confirmed in game; the rest unconfirmed |
| of which Optimus stopgap | 27 | 1% | low: placeholders until captured |
| No values | 534 | 14% | mostly battle triggers and main-hand procs, which never reach the panel; some real gaps among them |

**Estimate (not measured):** for typical endgame grids (Optimus, Omega or Odious with Opus, Destroyer, Celestial, Ultima and similar), 95%+ of panel lines should be exact; for grids leaning on event or collab weapons, more like 85–90%. Estimated DMG follows the panel: when every line matches, it matches too. The largest remaining sources of error, in order: the stopgap rows, the unconfirmed borrowed curves (HP Medium/Big, ATK Small), real effects hidden among the versions with no values, and battle-state conditions. An audit of the 534 versions without values would turn the estimate into a measurement.

## Next captures

In priority order: where the calculator has the least evidence for the most rows.

- [ ] **[Collection fallback captures](#collection-weapons)**: True Purity Sunblade (EX Stamina) and Wilnas's Finger (EX Enmity). Advocatus Diaboli is done (MjthwV).
- [ ] **[Armed curve checks](#armed-curve-checks)**: F2 Resentment's Gaze (SL10), W1 Windhose (SL15), W3 Daur da Blao (SL20).
- [ ] **[Main-hand swap M5](#main-hand-swaps-m1m5)**: Edem (Enmity at SL1).
- [ ] **[#17 Odious below the cap](#17-odious-below-the-cap)**: the Taboo aura between its base and its cap, verified only at the cap.
- [ ] **[The other element-session captures](#other-element-session-captures)**: Proven awakenings (#15), Malus (#14), covenants (#16).
- [ ] **[#2 HoEE8b](#2-hoee8b-dark-no-job)**: the last exact rebuild. Once it's in, the parity baseline can be deleted.
- [ ] **[#8–#13](#partly-recorded-grids)**: partly recorded grids.
- [ ] **XZq7xW**: the contributor re-imports the party so its exorcision levels and befoulments come through.

### Open questions

- **`reduction_effect_value` on Odious weapons.** An unknown field in each Odious weapon's `odiant` block: 180 on a Demonspear at exorcision 5/5, 0 on everything else. One deck JSON with Verboten weapons at different exorcision levels shows what it is.
- **The HP slider's 1% point.** At 1%, XfBq6u reads as if HP were about 0.1–0.25% (Ω Enmity 350 vs our 345.17, DEF 64.8 vs 64.58, Rightway's C.A. DMG 0), while LqZ4tM's Persistence reads exactly 1% (10,200). The curves themselves are right at 10% and 5%.
- **Undersky's Whispers' value.** MjthwV's Estimated DMG rises 11.131% × (1+2r)r, which is 11.13 at SL20 if the skill is a separate multiplier; our row still carries the stopgap 13.5. Hidden stats can't be checked against the panel, so this needs an Estimated DMG model or a second source.
- **Malus below SL20** (#14): every Malus you own is 5★, so only SL20 can be captured for now.

## Before you capture

1. **Your own account.** Grids from other players can't pin values that depend on their account (skill levels, awakenings).
2. **Outside Arcarum.** Sephirath base skills are Arcarum-only. Use a raid with the slot count the grid needs: 10 or 13 weapons.
3. **Import the party from the game right before capturing,** so uncaps, transcendence, keys, awakenings, AX skills, Odious data and skill levels all match. Check the **friend summon** in particular: the import takes whatever the deck has saved (WpPucd first came in with a stale one), and the team page must list it: the panel's enhancement header counts the support summon (RKY1Eb first had only the main Varuna, so its Optimus read half). Parties saved before 2026-10-16 with AX or Odious weapons need a fresh import.
4. **A test slot is a main-grid slot.** Extra slots only take certain series.
5. **Stash weapons** (not in your collection): save the party as private. Once I've exported the fixture, you can delete it.
6. **Screenshot both panel pages,** including the Estimated DMG / to-element / Max HP header. For a capture at full HP and default conditions, paste the deck JSON too: it has every line's exact value (230.5 where the panel shows 230). Calculator Conditions (HP slider, foe element) are HTML only, so HP sweeps still need screenshots.
7. **HP sweeps:** set the Calculator Conditions HP slider to each point, with one capture each.

Skill levels come from the import, so there's no need to report them. Element-changeable weapons (Celestial, Superlative and others) are set to the grid's element.

## Base grids

| Base | Element | Build | Status |
|---|---|---|---|
| **jFY42F** | Dark | LGZkRG recaptured after an Opus key change (LD66IX with one Executioner swapped for Hollowsky Blade). Use it in place of LGZkRG. | captured |
| **UC3M0M** (F0) | Fire | Higurashi (6★ T5) MH; Colossus Cane Ira ×3; Colossus Cane Omega ×2; Scythe of Repudiation (6★ T5, γ Pendulum + Pendulum of Supremacy); Sol Remnant; Doombringer Sword (Anklet of Ascendance); Heat of The Sun; two empty slots. Agni 6★ T5 main and friend. | captured |
| **W0** | Wind | HDJE0N with Piercing Galewing removed (the test slot). Zephyrus 6★ T5 main and friend. | **not captured** |
| **YCKMmk** | Water | Hraesvelgr (6★ T5) MH; Leviathan Gaze Omega ×3; Leviathan Gaze Mare ×2; Staff of Renunciation (6★ T5, Δ Pendulum + Chain of Falsehood); Doombringer Edge (Anklet of Oblivion); two empty slots. Leviathan Omega 6★ T5 main and friend, Wedges of the Sky sub. | captured |
| **RKY1Eb** | Water | Exo Ephialtes (5★) MH; Spirit of Mana ×3 (4★). Varuna 6★ main and friend. A small grid for main-hand swaps. | captured |
| **E0** | Earth | 7AiIOo with both World Enders removed, nothing in their slots | captured (PrXqh2) |
| **7AiIOo** | Earth | as captured | captured |
| **ZSEUmr** | Light | Rhongomyniad (5★) MH, Lantern Blade, Asclepius Rod, Frilly Charm Bracelet; free sub slots. Luminiera Omega 6★ main and friend. | captured |

## Recipes

### Fallback curves

The fallback-curve fix (live since 2026-10-16, #592) gives a skill with no family of its own the curve of its own series. ATK Big, Armed and ATK Medium are confirmed. The captures below pin the groups that aren't. Some follow an EX row that's missing values; others, marked *stopgap*, borrow the Optimus curve because no EX curve exists.

#### Earth stash party (E0–E2)

| # | Weapon (stash) | Slot | Its skills | Tests |
|---|---|---|---|---|
| E0 | — | — | — | the base (see [Base grids](#base-grids)); capture first |
| E1 | Baihu Fangstaff (4★, SL15) | a World Ender slot | Terra's Might, Terra's Third Spur | C.A. DMG and Might at SL15 |
| E2 | Seaside Guardian (3★, SL1) | the other World Ender slot | Resilient Grounds (its Synchronized Artistry only works as main hand) | HP, EX Big (6 at SL1) |

Capture E0, then E0 with E1 and E2 together (they sit on different panel lines).

#### Main-hand swaps (M1–M5)

These skills work only from the main hand ("When main weapon (MC only)"). Each is one capture: the base with only its main hand swapped.

| # | Weapon (stash) | Element | Its skills | Tests | Base |
|---|---|---|---|---|---|
| M1 ✓ | Asauchi (4★, SL15) | Fire | The Origin of All Zanpakuto, Nameless Zanpakuto | DA 20 / TA 10, fixed (QmQaPH) | UC3M0M, Higurashi → Asauchi |
| M2 ✓ | Xingese Liuyedao (4★, SL15) | Dark | Twelfth Crown Prince's Favorite, Xingese Blade | Critical 30 at SL15 (CrPnZ9) | XWhkW9, main hand → Xingese Liuyedao |
| ~~M3~~ | ~~Astro Modele~~ | | | not needed: GameWith gives Synchronized Artistry a fixed DA 20% / TA 10% (and it unlocks at weapon level 100), so the "multiattack rate" main-hand skills are curated flat | |
| M4 ✓ | Air Cannon (3★, SL1) | Water | Bang!, Air Blast | Critical 30 at SL1 too, so fixed (4pWKNB) | RKY1Eb, Exo Ephialtes → Air Cannon |
| M5 | Edem (4★, SL1) | Earth | Golden Spirit, Sentient Simulacrum | Enmity Big at SL1 | 7AiIOo at **HP 50%**, as is and with Andromeda → Edem |

M1 and M2 pinned SL15; M4 showed the main-hand Critical skills don't level.

#### Collection weapons

- [ ] **EX Stamina, Sunveil's Radiance** (*stopgap*): True Purity Sunblade 4★ (SL15), then 5★ (SL20), each in a free sub slot of ZSEUmr, HP 100%. Read **Stamina**.
- [x] **EX Enmity, Undersky's Whispers** (*stopgap*): the skill is **main hand only** (a sub-slot Advocatus adds nothing at any HP: aDkEIX). Captured as MjthwV: no panel line at any HP, so the row is `panel_hidden` and shows under Hidden stats. Its value is still the stopgap: the Estimated DMG rise implies 11.13 at SL20 if it's a separate multiplier (open).
- [ ] **EX Enmity, Firestorm's Enmity** (*stopgap*): Wilnas's Finger 4★ (SL15) in F0's test slot, at **HP 50% and 25%**, with and without it.

#### Still to find

Not in your collection or stash at a useful level. Any one weapon per group, at a known skill level:

| Group | Rows | Panel line | Weapons |
|---|---|---|---|
| EX DA/TA (*stopgap*) | the rest | DA Rate, TA Rate | Noble's Dance (Luin), Ophidian Servitor (Ouroboros), Royal Wing Barrier (Pilum), Swiftblade Oath (Hoarfrost Blade Persius), Dexterity (Guivre Rod), Skull Parade (Skull Wand), Cuttlefish's Cut (Squid Hand), Wild Wanderer (Vassago), Triple Talon Hellion (Coco & Mimi), Incantation Fang (Medusiana Staff), Solo (Vyrnstrument) |
| EX Critical (*stopgap*) | 8 | Critical | Full-Auto Fire (Assault Rifle (Man-Portable)), Ghost on the Battlefield (Soldier Bow), Unblinking Stare (Revolvyrn), Piercing Fang (Brionac), Spearsquid Flash (Squidpiercer) |
| EX Enmity (*stopgap*) | 2 more | Enmity (HP 50/25%) | Magic Charge (Fonic Rod), Audacity (Thunder Dirk Jove) |
| EX HP Big | 10 | HP | any Resilient weapon or Mysterious Wand at **SL15 or SL20** (the EX row stops at SL10) |
| EX HP Medium | 13 | HP | Willed Blaze/Flood/Grounds/Gale (Miner's Lantern, Shark Bouquet, Beach Flag, Achromatic Palette, …), Mysterious VIT (Mysterious Hammer/Harp/Hatchet, Pina Colata Bow, Sombre Gauntlet, Tadpole Tail), Downfall of Ignorance (Iridescent Bow). Mysterious Hatchet also pins EX HP Small at SL15. |
| EX ATK Small | 3 | EX Might | Speed Cast (Fonic Rod), All-Night Party (Spirit Seeker), Succession of Knighthood (Brand of Binding Oath), at **SL20** |
| Odious HP/Enmity Small (*stopgap*) | 2 | HP, Od Enmity | Taboo Netherfell's Aegis (Codex of Sanctity Verboten), Taboo Doomfire's Enmity (Karmasword of Prosperity Verboten) |

#### Armed curve checks

The Armed curve is 6/15/18/20 (SL1/10/15/20), captured on Armed Shadow. These check other skill levels and elements.

| # | Base | Test weapon | Expect |
|---|---|---|---|
| F2 | F0 | Resentment's Gaze 3★ (Armed Blaze, SL10) | EX Might +15 |
| W1 | W0 | Windhose 4★, no awakening (Armed Gale, SL15) | EX Might +18 |
| W3 | W0 | Daur da Blao 5★ (Armed Gale, SL20) | EX Might +20 |

### #17 Odious below the cap

The Taboo aura is modelled as linear between its base and its cap at 20 exorcision levels (1/2/2.5/3% per level at 0/3/4/5★, gbf.wiki/Belmervolk). Read the **Od** number in the panel header.

- [ ] **Fire:** 0ZA6Ak with one Deathcannon of Prosperity Verboten removed (3 Odious weapons at exorcision 5 = 15 levels). Expect Od **302.5%** (Belmervolk 4★ 137.5 + 5★ friend 165).
- [ ] **Water:** YCKMmk with Nihuyvintae 5★ as main summon and four 0★ Terrorbow of Mortality Verboten (exorcision 1) in the Gaze Mare and empty slots; a non-Odious friend summon. Expect Od **132%** (3.0% × (40 + 4 levels)).

### Other element-session captures

Each goes in its base's test slot, one at a time.

| # | Base | Test weapon | Tests |
|---|---|---|---|
| F3 | F0 | Ushumgal 5★, Attack awakening 15 | #15 Armed Blaze at SL20 with the Attack awakening |
| F4 | F0 | Ushumgal 5★, Special awakening 15 | #15 the Special awakening instead |
| F5 | F0 | Ray of Zhuque Malus 5★ | #14 Malus at SL20 |
| F6 | F0 | Wilnas's Finger 4★ | #16 Vermillion Covenant as a sub |
| F7 | F0, main hand → Wilnas's Finger 4★ | — | #16 Vermillion Covenant as main hand |
| W2 | W0 | Windhose 5★, Attack awakening 15 | #15 at SL20 with the Attack awakening |
| W4 | W0 | Qinglong Spear Malus 5★ | #14 Malus at SL20 |
| W5 | W0 | Ewiyar's Beak 4★ | #16 Ewiyar's covenant as a sub |
| A3 | YCKMmk | Wamdus's Cnidocyte 4★ | #16 Azure Covenant as a sub |
| A4 | YCKMmk | Hollowsky Staff 4★ | #16 Hollowsky covenant (Water) as a sub |

What these answer:
- **#14 Malus:** "<Element>'s Might" and "Essence of the <Direction>" (SL20 confirmed on Xuanwu Mace Malus, enTSuN).
- **#15 Proven "Armed" skills** with awakenings. Bismarck's Special lv15 gives Skill DMG Cap +10 and DMG Cap +3; Clarion's Attack lv15 adds EX Might 15.
- **#16 Covenants:** which covenant lines the panel shows, as main hand and as a sub. Fediel's Spine's Black Covenant is verified; Hollowsky Blade's shows nothing as a sub.

### #2 HoEE8b: Dark, no job

**Validates:**
- specialty inferred from the main hand
- Garrison at full HP (0)
- Draconic Provenance progression
- Telumas

**Reference:** `HoEE8b.json` (foe Light, optimus 460 / omega 20)

**Job:** none. Save the party with no job selected. 13 weapons.

| Slot | Weapon | State |
|---|---|---|
| MH | Ereshkigal | transcendence 5 |
| | Causality Driver ×2 | |
| | Second Float of the Herd | |
| | Executioner ×2 | |
| | Excalibur | element → Dark |
| | Pain and Suffering ×2 | |
| | Katana of Repudiation | transcendence 5; your Pendulum of Supremacy is fine (LD66IX used it too) |
| | Demolition-Tiger Axe | element → Dark; Attack awakening lv5 |
| | Festering of Mournful Obsequies | 5★; Aureole Teluma + Optimus Teluma |
| | Doombringer Lyre | 5★; Anklet of Oblivion |

**Summons:** Hades 250 (main and friend). Subs: Orologia, Bahamut 250, Sariel, Lucifer 250, Death, Fediel.

**Capture:** the base grid. All weapons are in your collection.

### Partly recorded grids

The old notes don't name every weapon in these. Fill the gaps with whatever you'd normally run, and tell me what you used.

#### #8 XJZZmv: Light Omega AX, Nighthound

**Validates:**
- seven AX lines, including Skill DMG Supp. lv3
- Selas (Arche) adding +20 to both the normal and omega enhancements
- the six-dragon sub-aura channel (Lu Woh's sub aura)
- astral weapons' enhancement counting for Optimus only

**Reference:** `XJZZmv.json`

**Weapons:** Flamma Orbis (MH); Luminiera Sword Omega ×4 with AX; True Purity Sunblade; Huanglong Katana; Sword of Renunciation (yours is transcendence 5, the old capture had 3); Cosmic Sword; one unknown slot.

**Crew:** Selas (Arche) with Grand Sandalphon in the backline. **Summons:** one sub is Lu Woh 3★.

**Capture:**
1. with Sandalphon (enhancements 60/400);
2. without him (40/380).

#### #9 HDbPnu: Dark rarities grid, no job

**Validates:**
- awakenings by series
- skill-level overrides
- the Coda character-race count

**Reference:** `HDbPnu.json`

**Weapons,** one per series: your Dark Illustrious (MH); any Malice, Epic, Regalia and Astral; Exo Hamartia (Special lv10); Forsaken Agastia (yours is Attack lv1, keep it); Cortana (SL1, unfed); any Dark Bahamut Coda; Advocatus Diaboli.

**Crew:** MC, Zeta, Sariel, Koku, Orologia, Wamdus (the race mix matters for Coda's Vita).

**Capture:**
1. the base grid;
2. one capture per weapon removed;
3. a main-hand swap to Trick Stick.

#### #10 NEKVvF: Dark, Monk, pendulum ≥ 280

**Validates:**
- Pendulum of Supremacy: its base Skill DMG Cap and the ≥280 package
- the Exo main-hand-only awakening (Attack type)
- Gauph Courage (Critical 20)
- Gauntlet Voltage II and Realm-Breaker's Animus II
- Fediel's ancestral stamina

**Reference:** `NEKVvF.json`

**Weapons:** Exo Hamartia (MH, Attack lv10); Covenant-Ruin Fist (you have one, not two); Fediel's Spine; Bismarck 5★ (the Armed Shadow weapon); Katana of Repudiation (Pendulum of Supremacy, opus boost ≥ 280%); no Ultima has Gauph Key of Courage, so use any Dark weapon in that slot and tell me which.

**Capture:**
1. friend Celeste 6★;
2. friend Bahamut T5.

#### #11 JBDMhV: Wind, Manadiver

**Validates:**
- Sp. C.A. Cap (Sword's Charge per sabre, γ Pendulum's transcendence upgrade)
- the Wrath family on EX Might Sp.

**Reference:** `JBDMhV.json`

**Weapons:** Petit Bouquet de Fleurs (MH); Sette di Spade ×2 (Attack 15, Defense 15); Sette di Spade Mk II ×2 (Attack 20, Defense 20); Reunion (Healing lv4); Spear of Renunciation (6★ T3; check its keys are γ Pendulum + Chain of Restoration).

**Summons:** Zephyrus 6★ (main and friend). **Capture:** the base grid.

#### #12 hbeZ3N: Water, Bandit Tycoon

**Validates:**
- the Δ Pendulum package (C.B. DMG Cap, FC DMG Cap)
- Clarion's Attack awakening (EX Might)

**Reference:** `hbeZ3N.json`

**Weapons:** Twinfall-Sky Blade; Clarion (record its Attack awakening level); Kris of Hypnos; Staff of Renunciation (yours has β + Chain of Falsehood, so the Δ lines won't appear); Worldbreaking Tauros 4★; Aquamarine Hatchet; daggers with Voltage II (4 daggers in total; you don't own these).

**Capture:**
1. the base grid;
2. without Twinfall;
3. with Kris of Hypnos as MH in place of Clarion.

#### #13 fsl8DD: Water Vitality

**Validates:** the Vitality formulas (EX Might, DEF and DMG Cap (Sp.) from Max HP).

**Reference:** `fsl8DD.json`

**Build:** one Calamitous Aquashade 4★ (SL15); Varuna 6★ T5 main and friend. **Capture:** HP 100%, and note the in-game Max HP.

## Done

| # | Grid | Captured as | Result |
|---|---|---|---|
| 1 | R1ckYi's design (Pendulum of Supremacy in place of Sagacity) | LD66IX | every line matches |
| 3 | K4UydX's design | 7AiIOo | every line matches |
| 4 | SPhnLB's design | HDJE0N | every line matches |
| 5 | Dark Omega HP sweep (OlFQ2a's design, Pendulum of Supremacy in place of Chain of Falsehood) | XfBq6u at 100/75/50/25/10/5/1% | every line matches except the 1% point (see [Open questions](#open-questions)); Rightway Pathfinder has no sub-25% cutoff |
| 6 | Dark Optimus HP sweep (QJ9736's design) | nCvV1x (100%, 10 weapons); LqZ4tM at 75/50/25/1% (13 weapons) | every line matches |
| 7 | qBOvon's design | 0ZA6Ak; plktjH (no Mortality Bow Mk II); k2hvSF (no Mortality Bow Mk II or Moros) | every line matches |
| 18 | Blazing Chain's supplement | WpPucd | C.A. Supp. 400,000 below its cap; the MC's own charge bar gain counts (Dainsleif) |
| 19 | Dark session (fallback curves) | LGZkRG (base), C1UGnK (Bismarck 4★), FaJB80 (Bismarck 5★), GmPPWw (Qilin Sword) | Armed Shadow 18 at SL15 and 20 at SL20; Clouds of Nightfall 21 at SL20 |
| 19 | Water session A0–A2 | YCKMmk (base), 2aH20k (Zodiaco Vitae), enTSuN (Xuanwu Mace Malus) | Clawed Flood 14.5 at SL15; Malus matches at SL20 |
| 20 | Light stash parties (L1–L3) | SAlNoF, ZSEUmr | Grace of Healing is a healing boost (no Heal Cap line); Pumpkin Trick Critical 3.2 and Resilient Shine HP 6 at SL1 |
| 19 | Earth stash party (E0–E2) | PrXqh2 (base), tIQu43 (Baihu Fangstaff, Seaside Guardian) | Terra's Might Big 18 at SL15; Resilient Grounds HP 6 at SL1; Terra's Third Spur ("for an earth ally in third position") doesn't reach the MC's panel, so it and the other two position-targeted Beast skills are suppressed |
| 19 | Fire base and M1 | UC3M0M (F0), QmQaPH (Asauchi as main hand) | every line matches: Nameless Zanpakuto EX Might 18 at SL15; The Origin of All Zanpakuto DA 20 / TA 10, fixed, which with GameWith's Astro Modele page curates all 23 "multiattack rate" main-hand skills (Synchronized Artistry, Climate Control) flat |
| M2 | Xingese Liuyedao as main hand | CrPnZ9 (HP 1%, turn 1; HP 100% at turns 1 and 5) | every line matches: Twelfth Crown Prince's Favorite gives Critical 30 at SL15, as the wiki says for Bang! ("a 30% boost to crit rate to the MC"), so all three main-hand "Massive boost to critical hit rate" skills (with First Comes Rock) are curated at 30; Hatred's Progression ×2 reads E. ATK (Prog.) 8 per turn |
| M4 | Air Cannon as main hand | RKY1Eb (base: Exo Ephialtes, three Spirit of Mana, Varuna main and support), 4pWKNB (Air Cannon at SL1) | every line matches: Bang! reads Critical 30 at SL1 as at SL15, so the three main-hand Critical skills are fixed at 30 (their in-game icon is the star used for special skills); Air Blast EX Might 6. Re-importing RKY1Eb after its support summon was added turned up a site bug: deleting a party with a main or support summon raised after the delete (fixed in #593, GBF-43). |
| — | Dark base and Advocatus Diaboli | jFY42F (new Dark base), aDkEIX (Advocatus 5★ in slot 7, HP 100–1%) | every line matches: Phantom's Supremacy EX Might 26 and True Phantom's Supremacy HP 16 at SL20; AX multiattack 2.5 and C.A. Supp. 5 (30,000). Undersky's Whispers is main hand only, so the panel doesn't change with HP; the EX Enmity capture moves to the main hand |
| — | Advocatus Diaboli as main hand | MjthwV (HP 100/75/50/25/1%) | every line matches. Undersky's Whispers shows no panel line at any HP, but Estimated DMG rises on the Enmity curve ((1+2r)r: 659126 → 686639 / 732495 / 796692 / 871618, exact at 75/50/25%). New `panel_hidden` flag: the row is kept off the panel and listed under Hidden stats |
| — | Contributed Water Odious grid | XZq7xW | confirms Odious Exalto ("Water Taboo" 25); the Taboo header and the Od and befoulment lines are open until the contributor re-imports |

<details>
<summary>Recipes for the done grids</summary>

#### #1 R1ckYi: Dark, Lancer Origin (captured as LD66IX)

| Slot | Weapon | State |
|---|---|---|
| MH | Ereshkigal | transcendence 5 |
| | Eternal Signature ×2 | |
| | Pain and Suffering ×2 | |
| | Executioner ×2 | |
| | Causality Driver ×2 | |
| | Katana of Repudiation | transcendence 5; β Pendulum + Pendulum of Supremacy |
| | Pain of Death | |
| | Demolition-Tiger Axe | Attack awakening lv5 |
| | Doombringer Lyre | 5★; Anklet of Oblivion |

**Summons:** Beelzebub 4★ main, Hades 6★ T5 friend, Fediel sub.

#### #3 K4UydX: Earth, Rising Force (captured as 7AiIOo)

| Slot | Weapon | State |
|---|---|---|
| MH | Andromeda | 5★ |
| | Bloodwrought Coral ×3 | |
| | World Ender ×2 | |
| | Harp of Repudiation | transcendence 5; γ Pendulum + Pendulum of Sagacity |
| | Staff of the Medicinal Master ×2 | |
| | Ultima Staff | Gauph Key of Strength + α + Tria |
| | Bounty of Gracious Earth | Oblivion Teluma + Optimus Teluma |
| | Doombringer Trident | Anklet of Maximality |
| | Altruism-Soul Staff | Attack awakening lv5 |

**Summons:** Versusia main, Titan 6★ T5 friend; subs The Hanged Man, Galleon, Uriel.

#### #4 SPhnLB: Wind, Lancer Origin (captured as HDJE0N)

| Slot | Weapon | State |
|---|---|---|
| MH | Rhomphaia | transcendence 5 |
| | Orderbringer ×2 | |
| | Kaguya's Folding Fan ×2 | |
| | Vortex of the Void | Attack awakening lv4 |
| | Evanescence | Attack awakening lv4 |
| | Piercing Galewing | |
| | Claíomh Solais Díon | |
| | Spear of Repudiation | transcendence 5; β Pendulum + Pendulum of Extremity |
| | Selfless-Rift Spear | Attack awakening lv5 |
| | Worldvexing Angelos | Attack awakening lv10 |
| | Doombringer Gauntlet | 5★ |

**Summons:** Zephyrus 6★ T5 main and friend; subs Bastet, Ewiyar, Raphael.

#### #5 Dark Omega HP sweep (captured as XfBq6u)

Excalibur MH; Celeste Claw Omega ×3 (AX ATK 2.5 + Skill DMG Cap 1; C.A. 6 + Ele. ATK 2; none); Celeste Grace Ater ×3; Fediel's Spine ×2 (AX HP 6 + Stamina 2; HP 3 + Stamina 3); Katana of Renunciation T3 (β Pendulum + Pendulum of Supremacy). Celeste Omega 6★ T5 main and friend, Fediel sub. Fighter Origin.

#### #6 Dark Optimus HP sweep (captured as nCvV1x and LqZ4tM)

Excalibur MH; Fallen Sword ×4 (Multiattack 4/4/1/1); Eternal Signature ×2; Herb Basket; Third Stripe of the Streak; Daodao Fu. LqZ4tM adds Pain of Death, Doombringer Lyre (Anklet of Oblivion) and Demolition-Tiger Axe (Attack lv5). Hades 6★ T5 main and friend, Fediel sub. Fighter Origin.

#### #7 qBOvon rebuild: Fire Odious / Taboo (captured as 0ZA6Ak)

| Slot | Weapon | State |
|---|---|---|
| MH | Higurashi | 6★, transcendence 5 |
| | Colossus Cane Ira ×3 | |
| | Deathcannon of Prosperity Verboten ×2 | exorcision 5 |
| | Demonspear of Prosperity Verboten ×2 | exorcision 5 |
| | Scythe of Renunciation | transcendence 5; α Pendulum + Chain of Temptation |
| | Mortality Bow Mk II | Special awakening lv20 |
| | Doombringer Sword | Anklet of Ascendance |
| | Heat of The Sun | |
| | Worldforging Moros | C.A. awakening lv10 |

**Summons:** Belmervolk 4★ main, 5★ friend. Kengo.

</details>
