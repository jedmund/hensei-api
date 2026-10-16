# W9: golden grids to build

Golden parties are real in-game captures of the weapon panel ("Weapon Skill Boosts") that CI checks the calculator against. Fourteen were lost on 2026-07-06. Their **panel references survive** in `data/panel_references/`.

Each grid below was reconstructed from its reference's notes.
- **If you rebuild a grid exactly** (same weapons, uncaps, transcendence, keys, awakenings, skill levels and summons), the old reference already holds the expected values. Your capture just has to match it.
- **If something differs,** that's fine. Capture anyway and tell me what changed; I'll write a new reference.

## Status

| # | Grid | Captured as | State |
|---|---|---|---|
| 1 | R1ckYi's design (Pendulum of Supremacy where R1ckYi had Sagacity) | LD66IX | every line matches; CI fixture |
| 3 | K4UydX's design | 7AiIOo | every line matches; CI fixture |
| 4 | SPhnLB's design | HDJE0N | every line matches; CI fixture |
| 7 | qBOvon's design | 0ZA6Ak, plus plktjH (no Mortality Bow Mk II) and k2hvSF (no Mortality Bow Mk II or Moros) | every line matches; CI fixtures |

Still wanted, in priority order: 5 and 6 (the HP sweeps), 2, then 17 to 20 (single-value questions), 14 to 16, and 8 to 13.

## Capture rules (from past rounds)

1. **Your own account.** Grids submitted by others can't pin values that depend on their account state (skill levels, awakenings).
2. **Outside Arcarum** (Sephirath base skills are Arcarum-only). Use a raid with the slot count the grid needs: 10 or 13 weapons.
3. **Set the party public** on granblue.team. Record every weapon's uncap, transcendence, keys, awakening type and level, and any skill level below the uncap's default. The extension syncs `skillLevel`.
4. **Screenshot both panel pages,** and include the Estimated DMG / to-element / Max HP header.
5. **Send me the party link and the screenshots.**
6. **HP sweeps:** set the Calculator Conditions HP slider to 100, 75, 50, 25 and 1, with one capture each.
7. **When asked for remove-and-diff:** one capture per removed weapon, with everything else unchanged. Recapture the base state between removals; a stale grid state once faked two wrong conclusions.

Element-changeable weapons (Celestial, Superlative and others) are listed with their default element; set them to the grid's element.

## A. Exact rebuilds (old reference reused)

### 1. R1ckYi: Dark, Lancer Origin, 13 weapons (captured: LD66IX)
**Validates:** Illustrious u1 upgrades, Gugalanna's charge gain −200, key pools, Demolition-Tiger's awakening. **Reference:** `R1ckYi.json` (foe Light, enhancements optimus 290 / omega 20).

| Slot | Weapon | State |
|---|---|---|
| MH | Ereshkigal | transcendence 5 |
| | Eternal Signature ×2 | |
| | Pain and Suffering ×2 | |
| | Executioner ×2 | |
| | Causality Driver ×2 | |
| | Katana of Repudiation | transcendence 5; keys β Pendulum + Pendulum of Sagacity |
| | Pain of Death | |
| | Demolition-Tiger Axe | element → Dark; Attack awakening lv5 |
| | Doombringer Lyre | 5★; Anklet of Oblivion |

**Summons:** Versusia (main), Hades (sub), Hades (friend).

### 2. HoEE8b: Dark, no job, 13 weapons
**Validates:** specialty inferred from the main hand, Garrison at full HP (0), Draconic Provenance progression, Telumas. **Reference:** `HoEE8b.json` (foe Light, optimus 460 / omega 20). **Save the party with no job selected.**

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

### 3. K4UydX: Earth, Rising Force, 13 weapons (captured: 7AiIOo)
**Validates:** blanket amplification (caps, amps and supplementals ×4.0), specialty-hidden Ultima and Celestial pieces, the ≥280 Medicinal Master package. **Reference:** `K4UydX.json` (foe Water, optimus 300 / omega 0).

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

**Summons:** not in the notes. Use an earth optimus pair that gives optimus 300 (for example Titan-type), and tell me which.

### 4. SPhnLB: Wind, Lancer Origin, 13 weapons (captured: HDJE0N)
**Validates:** Added HP and Debuff Res. overskills, World awakening specialty pairing, Doombringer II tiers. **Reference:** `SPhnLB.json` (foe Earth, optimus 460 / omega 20).

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

### 5. OlFQ2a: Dark Omega HP sweep, Fighter Origin, 10 weapons
**Validates:** mixed-source stamina, omega enmity, the ancestral frame, AX stamina levels. **References:** `OlFQ2a_hp{100,75,50,25,1}.json` (foe Light, optimus 60 / omega 460). **Capture at all five HP points.**

| Slot | Weapon | State |
|---|---|---|
| MH | Excalibur | element → Dark |
| | Celeste Claw Omega ×3 | AX: ATK 2.5 + Skill Cap 1 / C.A. 6 + E.ATK 2 / none |
| | Celeste Grace Ater ×3 | |
| | Fediel's Spine ×2 | AX: HP 6 + Stamina 2 / HP 3 + Stamina 3 |
| | Katana of Renunciation | key Chain of Falsehood |

**Summons:** Celeste Omega-type (omega 460). Tell me which.

### 6. QJ9736: Dark Optimus HP sweep, Fighter Origin, 10 weapons
**Validates:** stamina, Garrison, Rightway Pathfinder, Persistence curves. **References:** `QJ9736_hp{100,75,50,25,1}.json` (foe Light, optimus 400 / omega 30). **Capture at all five HP points.**

| Slot | Weapon |
|---|---|
| MH | Excalibur (element → Dark) |
| | Fallen Sword ×4 |
| | Eternal Signature ×2 |
| | Daodao Fu |
| | Herb Basket |
| | Third Stripe of the Streak |

### 7. qBOvon rebuild: Fire Odious / Taboo, 13 weapons (captured: 0ZA6Ak, plktjH, k2hvSF)
qBOvon was another player's capture, and 7 of its lines depended on their account. Rebuild its composition on **your** account so every line counts. **Validates:** taboo exorcision scaling, befoulment Hit lines, Odious families. **Reference:** `qBOvon.json` for the lines that weren't account-dependent; I'll write a new one.

| Slot | Weapon | State |
|---|---|---|
| MH | Unsigned Kaneshige | element → Fire |
| | Colossus Cane Ira ×3 | |
| | Demonspear of Prosperity Verboten ×2 | exorcision 5; record the befoulments |
| | Deathcannon of Prosperity Verboten ×2 | exorcision 5; record the befoulments |
| | Scythe of Renunciation | transcendence 5; β Pendulum + Pendulum of Sagacity (or your keys; record them) |
| | Mortality Bow Mk II | record its awakening type and level |
| | Worldforging Moros | |
| | Heat of The Sun | |
| | Doombringer Sword | Anklet of Oblivion |

**Summons:** Belmervolk 4★ (main and friend). **MC:** record the class. Moros's Sephirath Eparc II only shows for sabre- or bow-specialty MCs.

## B. Partly recorded: rebuild what's known

The notes don't name every weapon in these grids. Fill the gaps with whatever you'd normally run, and tell me what you used.

### 8. XJZZmv: Light Omega AX, Nighthound
**Known:**
- Flamma Orbis (MH);
- Luminiera Sword Omega ×4, with AX; record all of it, since seven AX lines were validated, including Skill DMG Supp. lv3;
- True Purity Sunblade, Huanglong Katana;
- Sword of Renunciation (transcendence 3, SL20; β Pendulum + Chain of Temptation);
- Cosmic Sword.

**Unknown:** one slot.

**Crew:** Selas (Arche) plus Grand Sandalphon in the backline. Capture the A/B pair: with Sandalphon (enhancements 60/400) and without (40/380).

**Summons:** one sub is Lu Woh 3★.

### 9. HDbPnu: Dark rarities grid, no job
**Validates:** awakenings by series, skill-level overrides, the Coda character-race count. One weapon per series:
- **Illustrious MH:** your Dark Illustrious.
- **Malice:** any.
- **Epic:** any.
- **Exo Hamartia:** "Special" awakening lv10.
- **Forsaken Agastia:** Attack awakening lv20.
- **Regalia:** any.
- **Cortana:** **SL1**; leave it unfed.
- **Bahamut Coda:** any Coda; Dark.
- **Advocatus:** Xeno; **SL15**.
- **Astral:** any.

**Crew:** MC, Zeta, Sariel, Koku, Orologia, Wamdus. This mix of races matters for Coda's Vita.

Do the full remove-and-diff series again: one capture per weapon removed, plus a main-hand swap to Trick Stick.

### 10. NEKVvF: Dark, Monk, pendulum ≥ 280
**Known:**
- Exo Hamartia (MH; **Attack** awakening lv10);
- Covenant-Ruin Fist ×2 (Gauntlet Voltage II; Realm-Breaker's Animus II);
- Fediel's Spine (Black Covenant);
- one Armed Shadow weapon (for example Scarface or Daemonenschwinge);
- an Ultima weapon with Gauph Courage;
- a Dark Opus weapon with **Pendulum of Supremacy**, at an opus boost of 280% or more.

**A/B pair:** friend Celeste 6★, then friend Bahamut T5.

### 11. JBDMhV: Wind, Manadiver (your account)
**Known:**
- Petit Bouquet de Fleurs (MH);
- Sette di Spade ×2 (awakenings Attack 15 and Defense 15);
- Sette di Spade Mk II ×2 (Attack 20 and Defense 20);
- Reunion (Healing awakening lv4);
- Spear of Renunciation (6★, transcendence 3; γ Pendulum + Chain of Restoration).

**Summons:** Zephyrus 6★ (main and friend). Other slots aren't recorded.

### 12. hbeZ3N: Water, Bandit Tycoon (your account)
**Known:**
- Twinfall-Sky Blade (Dualblade Flash's Bond II);
- Clarion: record its Attack awakening level. The old capture predates Attack lv15.
- Kris of Hypnos;
- Staff of Renunciation (transcendence 5; Δ Pendulum);
- Worldbreaking Tauros 4★;
- Aquamarine Hatchet;
- daggers with Voltage II: 4 daggers in total.

Captures: the base grid, without Twinfall, and with Kris of Hypnos as MH in place of Clarion.

### 13. fsl8DD: Water Vitality
- One **Calamitous Aquashade at SL15**.
- Summons: Varuna (main and friend).
- HP at 100%. Note the in-game Max HP.

## C. New grids for W10 Track D

These weren't captured before. Each varies one thing, so the difference between captures isolates it.

### 14. Malus skill levels
**Question:** Malus values below SL20 are unverified. Their skills are "<Element>'s Might" I/II (II at level 101) plus "Essence of the <Direction>".
- **Grid:** any stable grid of one element plus **one Malus weapon**: Ray of Zhuque Malus (Fire), Xuanwu Mace Malus (Water), Qinglong Spear Malus (Wind) or Baihu Claw Malus (Earth).
- **Captures:**
  1. the Malus at SL20;
  2. at SL15;
  3. at SL10;
  4. at SL1 (for example a fresh copy, or capture as you level one);
  5. the Malus removed.
  
  Don't change anything else between captures.

### 15. Proven "Armed" skills
**Question:** Armed values are unverified, apart from Clarion's Armed Flood at SL20 = 35.
- **Grid:** any stable grid of the element plus **one** Armed Proven weapon: Ushumgal (Fire, Armed Blaze), Windhose (Wind, Armed Gale) or Gusisnautar (Light, Armed Shine).
- **Captures:**
  1. SL20 with no awakening;
  2. SL20 with its awakening (record the type and level);
  3. SL15 (or the lowest level you have);
  4. removed.

### 16. Covenants
**Question:** which covenant lines the panel shows, and under what conditions. Fediel's Spine's Black Covenant (C.A. supp 600k) is validated.
- **Grid:** one six-dragon weapon, such as Wilnas's Finger (Vermillion Covenant) or Wamdus's Cnidocyte (Azure Covenant), or one Hollowsky weapon, such as Hollowsky Blade (Calamitous Covenant).
- **Captures:**
  1. the weapon as **main hand**;
  2. the same weapon as a **sub**;
  3. removed.
  
  If the covenant depends on battle state, capture the panel in battle at the moment it's active too, and tell me the condition.

### 17. Odious exorcision below the cap
**Question:** the Taboo aura is modelled as linear in total exorcision levels, from the base (40 levels' worth of the uncap's rate) to the cap at 20 levels (gbf.wiki/Belmervolk: 1/2/2.5/3.0% per level at 0/3/4/5★). Only the cap is verified (0ZA6Ak: 4★ 150 + 5★ 180 = 330).
- **Grid:** 0ZA6Ak.
- **Captures:** the Taboo line with the four Odious weapons' exorcision levels summing to less than 20 (for example one weapon swapped for a lower-exorcision copy, or a fresh one at level 1). Record every Odious weapon's exorcision level. If you have a 5★ Nihuyvintae or a 4★ friend, a capture with that pair helps too.

### 18. Blazing Chain's C.A. supplement
**Question:** Blazing Chain (Higurashi main hand) is modelled as a 400,000 C.A. supplement, read from its "(Damage cap: 400,000)". In 0ZA6Ak the C.A. Supp. line is at its 1,000,000 cap, so the value wasn't visible.
- **Grid:** any grid with Higurashi as main hand whose C.A. Supp. reads below 1,000,000 (not orange).
- **Captures:**
  1. with Higurashi as main hand;
  2. the same grid with another main hand.

### 19. EX skills with no family of their own (fallback curves)
**Question:** about 480 generated rows on EX skills with no family borrow the Taboo curve. The build's fallback ranks curves by size, so the largest (Taboo ×1.2) wins. That's a bug in our code, not game behaviour, and nothing on the wiki ties these skills to Odious values. The plain EX curves differ at every skill level, so **one capture at a known SL, plus one with the weapon removed,** settles each case.

**Setup:** one stable grid of any element; keep it fixed for all of 19a–19d. For each test weapon, put it in the same slot, capture, then take it out and capture again. Record the test weapon's **skill level** each time. A second SL (for example a fresh SL1 copy) confirms the shape but isn't required.

| # | Skill type | Weapons (any one) | Panel line | We show now (SL1/10/15) | EX curve would give |
|---|---|---|---|---|---|
| 19a | ATK Big, 312 versions: the "Armed <element>" event SSRs and similar | Bident or Aburaboshi Ramen Flag (Armed Flood), Blade of Remorse (Armed Gale), Astro Modele (Armed Blaze), Bismarck (Armed Shadow), Autograph Art Sketchbook (Armed Shine), Agarthan Hunter's Dagger (Armed Grounds) | EX Might | 7.2 / 18 / 21.6 | 6 / 15 / 18 |
| 19b | ATK Medium, 134 versions: the "Clawed <element>" event SRs | Fire Starter or Astro Wand (Clawed Blaze), Alster Spear (Clawed Gale), Death Whip (Clawed Flood), Halite Axe (Clawed Grounds), Corn Slicer (Clawed Shadow), Bedazzled Dagger (Clawed Shine) | EX Might | 3.6 / 14.4 / 17.4 | 3 / 12 / 14.5 |
| 19c | HP Medium, 11 versions: the "Willed <element>" event SRs | Miner's Lantern (Willed Blaze), Shark Bouquet (Willed Flood), Beach Flag (Willed Grounds), Achromatic Palette (Willed Gale) | HP | 7.2 / 18 / 20.4 | 3 / 12 / 14.5 |
| 19d | DA + TA Medium (optional) | Anti-Asteroid Beam Cannon, Materpent Lyre or Seaside Guardian (Synchronized Artistry) | DA Rate, TA Rate | 1 / 4.2 / 6 | 0.8 / 3.5 / 5 |

An SR at SL1 is easy to get from a fresh drop, so 19b and 19c can cover two SLs cheaply. If the panel's change matches neither column, send it anyway: that means the EX template row itself needs fixing.

### 20. Grace of Healing
**Question:** Asclepius Rod's Grace of Healing ("boost to healing") is stored as a heal cap boost, with values borrowed from the Taboo curve. It might be a healing boost (回復性能), which the panel may not show at all, rather than a heal cap (回復上限).
- **Grid:** any grid plus **Asclepius Rod**.
- **Captures:**
  1. with it, and the skill's Japanese name from the weapon's detail screen;
  2. removed.

  If the panel shows no healing line for it, that answers the question too.

## Priority

1. **5 and 6, the HP sweeps.** They anchor every HP-scaled curve.
2. **2,** the rest of section A.
3. **17 to 20.** They pin values the current goldens can't show, and unblock W10's Taboo fallback and Grace of Healing.
4. **14 to 16.** These unblock W10 Track D.
5. **8 to 13,** as you have the weapons.

After all of section A has been captured again, the parity baseline can be deleted: the goldens and compiler specs carry the checking from then on. Still missing from section A: 2, 5 and 6.
