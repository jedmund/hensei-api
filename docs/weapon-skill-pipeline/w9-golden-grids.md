# W9: golden grids to build

Golden parties are in-game captures of the weapon panel ("Weapon Skill Boosts"). CI checks the calculator against them. Each grid below says what to build, what it proves, and what to capture.

## How to help

1. Pick the next unchecked grid in **[To do](#to-do)**.
2. Build it on your account, following the [capture rules](#capture-rules).
3. Send me the party link and the screenshots. I write the reference and fix whatever doesn't match.

A grid doesn't have to match exactly. If you're missing a weapon or key, use the closest thing you have and tell me what changed.

## To do

In priority order. The number is the grid's ID; other docs refer to it.

- [ ] **[#5](#5-olfq2a-dark-omega-hp-sweep)** and **[#6](#6-qj9736-dark-optimus-hp-sweep)**: the HP sweeps. They anchor every HP-scaled curve.
- [ ] **[#19](#19-ex-skills-with-no-family-fallback-curves)**: fallback curves. They back a fix that changes about 480 rows.
- [ ] **[#2](#2-hoee8b-dark-no-job)**: the last exact rebuild.
- [ ] **[#17](#17-odious-exorcision-below-the-cap)**, **[#18](#18-blazing-chains-ca-supplement)** and **[#20](#20-grace-of-healing)**: single-value questions.
- [ ] **[#14](#14-malus-skill-levels)**, **[#15](#15-proven-armed-skills)** and **[#16](#16-covenants)**: unblock W10 Track D.
- [ ] **[#8](#8-xjzzmv-light-omega-ax-nighthound) to [#13](#13-fsl8dd-water-vitality)**: partly recorded grids, as you have the weapons.

When #2, #5 and #6 are in, the parity baseline can be deleted: the goldens and compiler specs carry the checking from then on.

## Capture rules

1. **Your own account.** Grids from other players can't pin values that depend on their account (skill levels, awakenings).
2. **Outside Arcarum.** Sephirath base skills are Arcarum-only. Use a raid with the slot count the grid needs: 10 or 13 weapons.
3. **Set the party public** on granblue.team. Record every weapon's uncap, transcendence, keys, and awakening type and level. Also record any skill level below the uncap's default; the extension syncs `skillLevel`.
4. **Screenshot both panel pages,** including the Estimated DMG / to-element / Max HP header.
5. **HP sweeps:** set the Calculator Conditions HP slider to 100, 75, 50, 25 and 1, with one capture each.
6. **Remove-and-diff:** one capture per removed weapon, with everything else unchanged. Recapture the base state between removals; a stale grid once faked two wrong conclusions.

Element-changeable weapons (Celestial, Superlative and others) are listed with their default element; set them to the grid's element.

---

## Exact rebuilds

These rebuild lost goldens. Their old reference holds the expected values.

### #5 OlFQ2a: Dark Omega HP sweep
**Validates:**
- mixed-source stamina
- omega enmity
- the ancestral frame
- AX stamina levels

**Reference:** `OlFQ2a_hp{100,75,50,25,1}.json` (foe Light, optimus 60 / omega 460)

**Job:** Fighter Origin, 10 weapons.

| Slot | Weapon | State |
|---|---|---|
| MH | Excalibur | element → Dark |
| | Celeste Claw Omega ×3 | AX: ATK 2.5 + Skill Cap 1 / C.A. 6 + E.ATK 2 / none |
| | Celeste Grace Ater ×3 | |
| | Fediel's Spine ×2 | AX: HP 6 + Stamina 2 / HP 3 + Stamina 3 |
| | Katana of Renunciation | key Chain of Falsehood |

**Summons:** a Celeste Omega-type pair (omega 460). Tell me which.

**Capture:** all five HP points.

### #6 QJ9736: Dark Optimus HP sweep
**Validates:**
- stamina
- Garrison
- Rightway Pathfinder
- Persistence curves

**Reference:** `QJ9736_hp{100,75,50,25,1}.json` (foe Light, optimus 400 / omega 30)

**Job:** Fighter Origin, 10 weapons.

| Slot | Weapon | State |
|---|---|---|
| MH | Excalibur | element → Dark |
| | Fallen Sword ×4 | |
| | Eternal Signature ×2 | |
| | Daodao Fu | |
| | Herb Basket | |
| | Third Stripe of the Streak | |

**Capture:** all five HP points.

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
| | Katana of Repudiation | transcendence 5; β Pendulum + Pendulum of Sagacity |
| | Demolition-Tiger Axe | element → Dark; Attack awakening lv5 |
| | Festering of Mournful Obsequies | 5★; Aureole Teluma + Optimus Teluma |
| | Doombringer Lyre | 5★; Anklet of Oblivion |

**Summons:** Hades 250 (main and friend). Subs: Orologia, Bahamut 250, Sariel, Lucifer 250, Death, Fediel.

**Capture:** the base grid.

---

## Single-value questions

Each of these varies one thing, so the difference between two captures isolates it. Keep everything else unchanged between captures.

### #19 EX skills with no family (fallback curves)
**Validates:**
- the curve used by EX skills that have no family of their own

**Reference:** none yet.

**Why:** about 480 generated rows on these skills borrow the Taboo curve. The build's fallback picks the curve with the largest values, so Taboo (×1.2) wins. That's a bug in our code; nothing on the wiki ties these skills to Odious values. The plain EX curve differs at every skill level, so one capture at a known SL settles each row of the table.

**Setup:** one stable grid of any element, kept fixed for all of 19a–19d.

**Capture,** for each test weapon:
1. put it in the same slot and capture;
2. take it out and capture again;
3. record its skill level.

A second skill level (for example a fresh SL1 copy) confirms the shape but isn't required.

| # | Skill type | Weapons (any one) | Panel line | We show now (SL1/10/15) | EX curve gives |
|---|---|---|---|---|---|
| 19a | ATK Big (312 rows): "Armed" event SSRs | Bident or Aburaboshi Ramen Flag (Armed Flood), Blade of Remorse (Armed Gale), Astro Modele (Armed Blaze), Bismarck (Armed Shadow), Autograph Art Sketchbook (Armed Shine), Agarthan Hunter's Dagger (Armed Grounds) | EX Might | 7.2 / 18 / 21.6 | 6 / 15 / 18 |
| 19b | ATK Medium (134 rows): "Clawed" event SRs | Fire Starter or Astro Wand (Clawed Blaze), Alster Spear (Clawed Gale), Death Whip (Clawed Flood), Halite Axe (Clawed Grounds), Corn Slicer (Clawed Shadow), Bedazzled Dagger (Clawed Shine) | EX Might | 3.6 / 14.4 / 17.4 | 3 / 12 / 14.5 |
| 19c | HP Medium (11 rows): "Willed" event SRs | Miner's Lantern (Willed Blaze), Shark Bouquet (Willed Flood), Beach Flag (Willed Grounds), Achromatic Palette (Willed Gale) | HP | 7.2 / 18 / 20.4 | 3 / 12 / 14.5 |
| 19d | DA + TA Medium (optional) | Anti-Asteroid Beam Cannon, Materpent Lyre or Seaside Guardian (Synchronized Artistry) | DA Rate, TA Rate | 1 / 4.2 / 6 | 0.8 / 3.5 / 5 |

19a and 19b cover most of the rows. If the panel's change matches neither column, send it anyway: the EX template row itself needs fixing.

### #17 Odious exorcision below the cap
**Validates:**
- the Taboo aura between its base and its cap

**Reference:** none yet.

**Why:** the aura is modelled as linear in total exorcision levels, capped at 20 levels (gbf.wiki/Belmervolk: 1/2/2.5/3.0% per level at 0/3/4/5★). Only the cap is verified (0ZA6Ak: 4★ 150 + 5★ 180 = 330).

**Grid:** 0ZA6Ak (see [#7](#7-qbovon-rebuild-fire-odious--taboo)).

**Capture:**
1. the four Odious weapons with exorcision levels summing to less than 20, for example one swapped for a lower-exorcision copy;
2. record every Odious weapon's exorcision level.

A capture with a 5★ Nihuyvintae pair (Water) helps too, if you have one.

### #18 Blazing Chain's C.A. supplement
**Validates:**
- Blazing Chain's 400,000 C.A. supplement, read from its "(Damage cap: 400,000)"

**Reference:** none yet.

**Why:** in 0ZA6Ak the C.A. Supp. line was at its 1,000,000 cap, so the value wasn't visible.

**Grid:** any grid with Higurashi as main hand whose C.A. Supp. reads below 1,000,000 (not orange).

**Capture:**
1. with Higurashi as main hand;
2. the same grid with another main hand.

### #20 Grace of Healing
**Validates:**
- whether Asclepius Rod's Grace of Healing is a heal cap (回復上限) or a healing boost (回復性能)

**Reference:** none yet.

**Why:** it's stored as a heal cap boost, with values borrowed from the Taboo curve. A healing boost might not show on the panel at all.

**Grid:** any grid plus Asclepius Rod.

**Capture:**
1. with it, plus the skill's Japanese name from the weapon's detail screen;
2. removed.

If the panel shows no healing line for it, that answers the question too.

---

## W10 Track D

### #14 Malus skill levels
**Validates:**
- Malus values below SL20: "<Element>'s Might" I/II (II at level 101) and "Essence of the <Direction>"

**Reference:** none yet.

**Grid:** any stable grid of one element plus one Malus weapon: Ray of Zhuque Malus (Fire), Xuanwu Mace Malus (Water), Qinglong Spear Malus (Wind) or Baihu Claw Malus (Earth).

**Capture:**
1. the Malus at SL20;
2. at SL15;
3. at SL10;
4. at SL1 (a fresh copy, or capture as you level one);
5. the Malus removed.

### #15 Proven "Armed" skills
**Validates:**
- Proven Armed values (only Clarion's Armed Flood at SL20 = 35 is verified)

**Reference:** none yet.

**Grid:** any stable grid of the element plus one Armed Proven weapon: Ushumgal (Fire, Armed Blaze), Windhose (Wind, Armed Gale) or Gusisnautar (Light, Armed Shine).

**Capture:**
1. SL20 with no awakening;
2. SL20 with its awakening (record the type and level);
3. SL15, or the lowest level you have;
4. removed.

### #16 Covenants
**Validates:**
- which covenant lines the panel shows, and when (Fediel's Spine's Black Covenant, C.A. supp 600k, is verified)

**Reference:** none yet.

**Grid:** one six-dragon weapon, such as Wilnas's Finger (Vermillion Covenant) or Wamdus's Cnidocyte (Azure Covenant), or one Hollowsky weapon, such as Hollowsky Blade (Calamitous Covenant).

**Capture:**
1. the weapon as main hand;
2. the same weapon as a sub;
3. removed.

If the covenant depends on battle state, also capture the panel in battle while it's active, and tell me the condition.

---

## Partly recorded grids

The old notes don't name every weapon in these. Fill the gaps with whatever you'd normally run, and tell me what you used.

### #8 XJZZmv: Light Omega AX, Nighthound
**Validates:**
- seven AX lines, including Skill DMG Supp. lv3
- Selas (Arche) adding +20 to both the normal and omega enhancements
- the six-dragon sub-aura channel (Lu Woh's sub aura)
- astral weapons' enhancement counting for Optimus only

**Reference:** `XJZZmv.json`

**Known weapons:**
- Flamma Orbis (MH)
- Luminiera Sword Omega ×4, with AX (record all of it)
- True Purity Sunblade
- Huanglong Katana
- Sword of Renunciation (transcendence 3, SL20; β Pendulum + Chain of Temptation)
- Cosmic Sword
- one unknown slot

**Crew:** Selas (Arche) with Grand Sandalphon in the backline.

**Summons:** one sub is Lu Woh 3★.

**Capture:**
1. with Sandalphon (enhancements 60/400);
2. without him (40/380).

### #9 HDbPnu: Dark rarities grid, no job
**Validates:**
- awakenings by series
- skill-level overrides
- the Coda character-race count

**Reference:** `HDbPnu.json`

**Weapons,** one per series:
- **Illustrious (MH):** your Dark Illustrious
- **Malice:** any
- **Epic:** any
- **Exo Hamartia:** Special awakening lv10
- **Forsaken Agastia:** Attack awakening lv20
- **Regalia:** any
- **Cortana:** SL1; leave it unfed
- **Bahamut Coda:** any Dark Coda
- **Advocatus:** Xeno; SL15
- **Astral:** any

**Crew:** MC, Zeta, Sariel, Koku, Orologia, Wamdus. The mix of races matters for Coda's Vita.

**Capture:**
1. the base grid;
2. one capture per weapon removed;
3. a main-hand swap to Trick Stick.

### #10 NEKVvF: Dark, Monk, pendulum ≥ 280
**Validates:**
- Pendulum of Supremacy: its base Skill DMG Cap and the ≥280 package (EX, C.B./FC Amp., C.A. Amp. (Sp.), DMG Cap)
- the Exo main-hand-only awakening (Attack type)
- Gauph Courage (Critical 20)
- Gauntlet Voltage II and Realm-Breaker's Animus II
- Fediel's ancestral stamina

**Reference:** `NEKVvF.json`

**Known weapons:**
- Exo Hamartia (MH; Attack awakening lv10)
- Covenant-Ruin Fist ×2 (Gauntlet Voltage II; Realm-Breaker's Animus II)
- Fediel's Spine (Black Covenant)
- one Armed Shadow weapon (for example Scarface or Daemonenschwinge)
- an Ultima weapon with Gauph Courage
- a Dark Opus weapon with Pendulum of Supremacy, at an opus boost of 280% or more

**Capture:**
1. friend Celeste 6★;
2. friend Bahamut T5.

### #11 JBDMhV: Wind, Manadiver
**Validates:**
- Sp. C.A. Cap (Sword's Charge per sabre, γ Pendulum's transcendence upgrade)
- the Wrath family on EX Might Sp.

**Reference:** `JBDMhV.json`

**Known weapons:**
- Petit Bouquet de Fleurs (MH)
- Sette di Spade ×2 (awakenings Attack 15 and Defense 15)
- Sette di Spade Mk II ×2 (Attack 20 and Defense 20)
- Reunion (Healing awakening lv4)
- Spear of Renunciation (6★, transcendence 3; γ Pendulum + Chain of Restoration)

**Summons:** Zephyrus 6★ (main and friend). Other slots aren't recorded.

**Capture:** the base grid.

### #12 hbeZ3N: Water, Bandit Tycoon
**Validates:**
- the Δ Pendulum package (C.B. DMG Cap, FC DMG Cap)
- Clarion's Attack awakening (EX Might; skipped in the old reference)

**Reference:** `hbeZ3N.json` (predates Clarion's Attack lv15, so record its level)

**Known weapons:**
- Twinfall-Sky Blade (Dualblade Flash's Bond II)
- Clarion (record its Attack awakening level)
- Kris of Hypnos
- Staff of Renunciation (transcendence 5; Δ Pendulum)
- Worldbreaking Tauros 4★
- Aquamarine Hatchet
- daggers with Voltage II: 4 daggers in total

**Capture:**
1. the base grid;
2. without Twinfall;
3. with Kris of Hypnos as MH in place of Clarion.

### #13 fsl8DD: Water Vitality
**Validates:**
- the Vitality formulas (EX Might, DEF and DMG Cap (Sp.) from Max HP)

**Reference:** `fsl8DD.json`

**Known:**
- one Calamitous Aquashade at SL15
- Summons: Varuna (main and friend)

**Capture:** HP at 100%; note the in-game Max HP.

---

## Done

| # | Grid | Captured as | State |
|---|---|---|---|
| 1 | R1ckYi's design (Pendulum of Supremacy where R1ckYi had Sagacity) | LD66IX | every line matches; CI fixture |
| 3 | K4UydX's design | 7AiIOo | every line matches; CI fixture |
| 4 | SPhnLB's design | HDJE0N | every line matches; CI fixture |
| 7 | qBOvon's design | 0ZA6Ak, plus plktjH (no Mortality Bow Mk II) and k2hvSF (no Mortality Bow Mk II or Moros) | every line matches; CI fixtures |

<details>
<summary>The recipes for the done grids</summary>

### #1 R1ckYi: Dark, Lancer Origin
**Validates:**
- Illustrious u1 upgrades
- Gugalanna's charge gain −200
- key pools
- Demolition-Tiger's awakening

**Reference:** `R1ckYi.json` (foe Light, optimus 290 / omega 20); captured as `LD66IX.json`

| Slot | Weapon | State |
|---|---|---|
| MH | Ereshkigal | transcendence 5 |
| | Eternal Signature ×2 | |
| | Pain and Suffering ×2 | |
| | Executioner ×2 | |
| | Causality Driver ×2 | |
| | Katana of Repudiation | transcendence 5; β Pendulum + Pendulum of Sagacity |
| | Pain of Death | |
| | Demolition-Tiger Axe | element → Dark; Attack awakening lv5 |
| | Doombringer Lyre | 5★; Anklet of Oblivion |

**Summons:** Versusia (main), Hades (sub), Hades (friend).

### #3 K4UydX: Earth, Rising Force
**Validates:**
- blanket amplification (caps, amps and supplementals ×4.0)
- specialty-hidden Ultima and Celestial pieces
- the ≥280 Medicinal Master package

**Reference:** `K4UydX.json` (foe Water, optimus 300 / omega 0); captured as `7AiIOo.json`

| Slot | Weapon | State |
|---|---|---|
| MH | Andromeda | transcendence 1 |
| | Bloodwrought Coral ×3 | |
| | World Ender ×2 | |
| | Harp of Repudiation | transcendence 5; α Pendulum + Pendulum of Sagacity |
| | Staff of the Medicinal Master ×2 | |
| | Altruism-Soul Staff | element → Earth; Attack awakening lv5 |
| | Bounty of Gracious Earth | Oblivion Teluma + Optimus Teluma |
| | Doombringer Trident | Anklet of Oblivion |
| | Ultima Staff | element → Earth; keys Gauph Strength / Δ / Tessera |

### #4 SPhnLB: Wind, Lancer Origin
**Validates:**
- Added HP and Debuff Res. overskills
- World awakening specialty pairing
- Doombringer II tiers

**Reference:** `SPhnLB.json` (foe Earth, optimus 460 / omega 20); captured as `HDJE0N.json`

| Slot | Weapon | State |
|---|---|---|
| MH | Rhomphaia | transcendence 5 |
| | Kaguya's Folding Fan ×2 | |
| | Piercing Galewing | |
| | Orderbringer ×2 | |
| | Evanescence | |
| | Vortex of the Void | Attack awakening lv4 |
| | Claíomh Solais Díon | |
| | Spear of Repudiation | transcendence 5; β Pendulum + Pendulum of Extremity |
| | Doombringer Gauntlet | 4★ |
| | Selfless-Rift Spear | element → Wind; awakening lv5 |
| | Worldvexing Angelos | awakening lv10 |

**Summons:** Zephyrus 6★ (main and friend).

### #7 qBOvon rebuild: Fire Odious / Taboo
**Validates:**
- taboo exorcision scaling
- befoulment Hit lines
- Odious families

**Reference:** `0ZA6Ak.json`, `plktjH.json`, `k2hvSF.json`

| Slot | Weapon | State |
|---|---|---|
| MH | Unsigned Kaneshige | element → Fire |
| | Colossus Cane Ira ×3 | |
| | Demonspear of Prosperity Verboten ×2 | exorcision 5 |
| | Deathcannon of Prosperity Verboten ×2 | exorcision 5 |
| | Scythe of Renunciation | transcendence 5 |
| | Mortality Bow Mk II | Special awakening lv20 |
| | Worldforging Moros | |
| | Heat of The Sun | |
| | Doombringer Sword | Anklet of Oblivion |

**Summons:** Belmervolk 4★ (main) and 5★ (friend).

</details>
