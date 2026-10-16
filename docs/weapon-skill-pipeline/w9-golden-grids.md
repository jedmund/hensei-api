# W9: golden grids to build

Golden parties are in-game captures of the weapon panel ("Weapon Skill Boosts"). CI checks the calculator against them. Each grid below says what to build, what it proves, and what to capture.

## How to help

1. Pick the next unchecked item in **[To do](#to-do)**.
2. Build it on your account, following the [capture rules](#capture-rules).
3. Send me the party link and the screenshots. I write the reference and fix whatever doesn't match.

Before you send a capture, check the [import checklist](#import-checklist): most wrong references so far came from the saved party not matching the game, not from the calculator.

Every weapon below is in your collection (checked 2026-10-15), at the uncap shown. The collection didn't record skill levels then, so the plans assume each weapon is at its uncap's maximum (3★ SL10, 4★ SL15, 5★ SL20, 6★ SL25). Since 2026-10-16 (API #588) the import stores each weapon's skill level from the game, so a party imported now carries its real ones.

## To do

In priority order: where the calculator has the least evidence for the most rows. The number is the grid's ID; other docs refer to it.

### Verification (checks a model we already have)

- [ ] **[Water session](#water-session) A1: Zodiaco Vitae (Clawed Flood, ATK Medium, SL15).** The most important capture right now. The fallback-curve fix moves 134 ATK Medium rows to the EX curve (3/12/14.5) with no in-game number behind them; the panel should add 14.5 at SL15.
- [ ] **[Fire session](#fire-session) F2: Resentment's Gaze 3★ (Armed Blaze, SL10).** Adds an SL10 point to the Armed curve (6/15/18/20); the panel should add 15.
- [ ] **[Wind session](#wind-session) W1 and W3**: Windhose 4★ (Armed Gale, SL15, no awakening) and Daur da Blao (Armed Gale, SL20). A second element for the Armed curve.
- [ ] **#17 Odious below the cap** (Fire session and Water session): the Taboo aura is modelled as linear between its base and its cap at 20 exorcision levels (1/2/2.5/3% per level at 0/3/4/5★), verified only at the cap.
- [ ] **The rest of the Fire, Wind and Water sessions**: Proven awakenings (#15), Malus (#14), covenants (#16).
- [ ] **[#2](#2-hoee8b-dark-no-job)**: the last exact rebuild.
- [ ] **[#8](#8-xjzzmv-light-omega-ax-nighthound) to [#13](#13-fsl8dd-water-vitality)**: partly recorded grids.
- [ ] **XZq7xW** (contributed Water Odious grid): ready for the contributor to re-import the party, so its exorcision levels and befoulments come through. See [Done](#done).

### New information (things we don't know yet)

- [ ] **Deck JSON with every capture.** The party-deck response the game sends (`deck.pc.damage_info`) holds the panel itself: every line's exact value (230.5 where the panel shows 230), the orange `is_max` flag, the three enhancement numbers, and the full weapon and summon state at that moment. Paste it alongside the screenshots, or instead of them. It settles rounding, catches a stale saved party, and shows fields we don't know about yet. (Kaneo GBF-41 makes this automatic later.)
- [ ] **`reduction_effect_value` on Odious weapons.** Unknown field in each Odious weapon's `odiant` block (180 on a Demonspear at exorcision 5/5, 0 on everything else). One deck JSON with Verboten weapons at different exorcision levels shows how it moves, and so what it is.
- [ ] **Omega enmity and Garrison near 0 HP.** XfBq6u matches at 25% and above but not at 1% (Ω Enmity 350 vs our 345.17, DEF 64.8 vs 64.58). XfBq6u at **10%** and **5%** HP maps the end of both curves.
- [ ] **Grace of Healing (#20)**: is it a heal cap or a healing boost? Needs Asclepius Rod, which isn't in your collection.

### Done

- [x] **[#5](#5-olfq2a-dark-omega-hp-sweep)** and **[#6](#6-qj9736-dark-optimus-hp-sweep)**: done 2026-10-16. XfBq6u (Omega) at 100/75/50/25/1% and nCvV1x/LqZ4tM (Optimus) at 100/75/50/25/1% match every line, except XfBq6u at 1% (Ω Enmity 350 vs 345.17, DEF 64.8 vs 64.58: the curves near 0 HP; Persistence pins the slider at exactly 1%).
- [x] **[Dark session](#dark-session)**: done 2026-10-16 (LGZkRG, C1UGnK, GmPPWw, FaJB80). ATK Big's fallback is wrong; Armed skills stop at 20 at SL20.
- [x] **#18 Blazing Chain's supplement**: done 2026-10-16 (WpPucd: C.A. Supp. 400,000 below its cap). Fire session F1 is no longer needed.

When #2 is in (#5 and #6 are done), the parity baseline can be deleted: the goldens and compiler specs carry the checking from then on.

## Import checklist

The reference is checked against the party as saved on granblue.team, so the saved party has to match the game exactly. Check these before sending:

- **Summons, especially the friend summon.** The import takes whatever the deck has saved. WpPucd first came in with a stale Belmervolk friend summon instead of the Colossus Omega used for the capture.
- **Re-import after 2026-10-16.** Before API #588 went live, imports dropped AX Skill DMG Cap rolls, befoulments, permeation, exorcision levels and skill levels. A party saved before then that has AX or Odious weapons needs a fresh import from the game; the import now keeps all of them.
- **Skill levels.** The import stores them from the game now, so a weapon below its maximum is handled automatically; there's no need to tell me.
- **Keys and awakenings.** The collection doesn't always list keys (your Renunciation weapons have none recorded), so check them on the party.

Later, the extension could capture the panel straight from the game: the deck response includes it (`damage_info.effect_value_info`, with the orange `is_max` flag and the enhancement numbers). That would remove the screenshots and catch every mismatch above automatically. It's filed as a feature (Kaneo GBF-41).

## Capture rules

1. **Your own account.** Grids from other players can't pin values that depend on their account (skill levels, awakenings).
2. **Outside Arcarum.** Sephirath base skills are Arcarum-only. Use a raid with the slot count the grid needs: 10 or 13 weapons.
3. **Set the party public** on granblue.team. Import it from the game right before capturing, so uncaps, transcendence, keys, awakenings, AX skills, Odious data and skill levels all match.
4. **Screenshot both panel pages,** including the Estimated DMG / to-element / Max HP header. If you can, paste the deck JSON too (see [New information](#new-information-things-we-dont-know-yet)).
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

**From your collection:** all owned, and your AX rolls match. Main summon Celeste Omega 6★ T5. The collection doesn't list the Katana of Renunciation's key: check it's Chain of Falsehood, or tell me what it has.

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

**Summons:** not in the notes. Hades 6★ T5 (main and friend) should be close; tell me what the header reads.

**From your collection:** all owned.

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

**From your collection:** all owned. Your Katana of Repudiation runs Pendulum of Supremacy, not Sagacity; that's fine (LD66IX did the same), just keep it.

**Capture:** the base grid.

---

## Element sessions

Each session answers several questions at once. Save the **base** grid with one main-grid slot left empty (the test slot; extra slots only take certain series), capture it, then put each test weapon in the test slot, one at a time, and capture again. Change nothing else between captures. A test weapon's value is its capture minus the base.

What the sessions answer:
- **#14 Malus:** values of "<Element>'s Might" and "Essence of the <Direction>". Your Malus weapons are all 5★, so this checks SL20 only.
- **#15 Proven "Armed" skills:** values at SL15 and SL20, with and without awakenings. Only Clarion's Armed Flood at SL20 (35) is verified.
- **#16 Covenants:** which covenant lines the panel shows, as main hand and as a sub. Fediel's Spine's Black Covenant is verified.
- **#17 Odious below the cap:** the Taboo aura between its base and its cap at 20 exorcision levels (gbf.wiki/Belmervolk: 1/2/2.5/3.0% per level at 0/3/4/5★). Read it from the "Od" number in the panel header.
- **#18 Blazing Chain's supplement:** Higurashi's C.A. supplement, modelled as 400,000. Every Fire golden so far hits the 1,000,000 cap because of the Odious weapons.
- **#19 Fallback curves:** about 480 rows on EX skills with no family borrow the Taboo curve, because the build's fallback picks the largest one. It's a bug in our code, not game behaviour. Each capture tells the two curves apart:

  | Skill | We show now (SL10/15/20) | EX curve gives (SL10/15/20) | Panel line |
  |---|---|---|---|
  | ATK Big ("Armed …", Clouds of Nightfall) | 18 / 21.6 / 21.6 | 15 / 18 / 21 | EX Might |
  | ATK Medium ("Clawed …") | 14.4 / 17.4 / 17.4 | 12 / 14.5 / 14.5 | EX Might |

  Neither borrowed curve has an SL20 value, so the calculator holds the SL15 one; the EX ATK Medium row stops at SL15 too.

  If a change matches neither column, send it anyway: the EX template row needs fixing then.

  **Dark session result:** the borrowed curve is wrong. Clouds of Nightfall gives 21 at SL20 (the EX curve). The "Armed" skills have their own curve: Armed Shadow gives 18 at SL15 and 20 at SL20 (6/15/18/20, like normal Might Big), which also fits Clarion's Armed Flood at 35 with an Attack awakening lv15. The fix waits on its own PR.

### Dark session
**Base:** LD66IX with **one Executioner** removed (that's the test slot). Same summons: Beelzebub 4★ main, Hades 6★ T5 friend, Fediel sub.

| Capture | Test slot | Answers |
|---|---|---|
| D0 | empty | the base |
| D1 | Bismarck 4★ (Armed Shadow, SL15) | #19 ATK Big at SL15 |
| D2 | Bismarck 5★ (Armed Shadow, SL20) | #19 ATK Big at SL20 |
| D3 | Qilin Sword 5★ (Clouds of Nightfall) | #19 ATK Big, a second skill on the same curve |
| D4 | Hollowsky Blade 4★ (Calamitous Covenant) | #16 Hollowsky covenant as a sub |

**Result (2026-10-16):**

| Capture | Party | EX Might | Other changes | What it showed |
|---|---|---|---|---|
| D4 (used as the base) | LGZkRG | 230 | none | Hollowsky Blade's covenant shows no line as a sub, so this capture is the base; every line matches |
| D1 | C1UGnK | 248 (+18) | Skill DMG Cap 65 | Armed Shadow at SL15 = 18 |
| D3 | GmPPWw | 251 (+21) | none | Clouds of Nightfall at SL20 = 21 |
| D2 | FaJB80 | 250 (+20) | Skill DMG Cap 75, DMG Cap Pen. 9.5 | Armed Shadow at SL20 = 20; the Special awakening lv15 gives Skill DMG Cap +10 and DMG Cap +3, which shows as DMG Cap Pen. +1.5 because DMG Cap is already at 20 |

The panel shows EX Might without its decimal (the base is 230.5). The three EX Might lines stay open until the fallback fix; every other line matches. D0 (an empty test slot) wasn't needed.

### Fire session
**Base** (10 weapons). It leaves out the Odious weapons, which pushed C.A. Supp. past its cap in every Fire golden so far. It doesn't need to be a strong grid, only the same between captures.

| Slot | Weapon | State |
|---|---|---|
| MH | Higurashi | 6★, transcendence 5 |
| | Colossus Cane Omega ×2 | 5★ |
| | Colossus Cane Ira ×3 | 4★ |
| | Scythe of Repudiation | 6★, transcendence 5; β Pendulum + Pendulum of Extremity |
| | Doombringer Sword | 5★; Anklet of Ascendance |
| | Heat of The Sun | 5★ |
| | *(test slot)* | |

**Summons:** Agni 6★ T5 main; friend Agni (any), and tell me which.

| Capture | Change | Answers |
|---|---|---|
| F0 | test slot empty | the base; #18 with Higurashi |
| ~~F1~~ | ~~main hand → Unsigned Kaneshige 5★ (Fire), test slot empty~~ | not needed: WpPucd answered #18 |
| F2 | Resentment's Gaze 3★ (Armed Blaze, SL10) | #19 ATK Big at SL10 |
| F3 | Ushumgal 5★, Attack awakening 15 | #15 Armed Blaze at SL20 with the Attack awakening |
| F4 | Ushumgal 5★, Special awakening 15 | #15 the Special awakening instead |
| F5 | Ray of Zhuque Malus 5★ | #14 Malus at SL20 |
| F6 | Wilnas's Finger 4★ | #16 Vermillion Covenant as a sub |
| F7 | main hand → Wilnas's Finger 4★, test slot empty | #16 Vermillion Covenant as main hand |

**Odious below the cap (#17):** separately, 0ZA6Ak with one **Deathcannon of Prosperity Verboten** removed (3 Odious weapons at exorcision 5 = 15 levels). Expected header: Od 302.5% (Belmervolk 4★ 137.5 + 5★ friend 165).

### Wind session
**Base:** HDJE0N with **Piercing Galewing** removed (that's the test slot). Same summons: Zephyrus 6★ T5 main and friend.

| Capture | Test slot | Answers |
|---|---|---|
| W0 | empty | the base |
| W1 | Windhose 4★, no awakening (Armed Gale, SL15) | #15 and #19 ATK Big at SL15 |
| W2 | Windhose 5★, Attack awakening 15 (SL20) | #15 at SL20 with the Attack awakening |
| W3 | Daur da Blao 5★ (Armed Gale) | #19 ATK Big at SL20, no awakening |
| W4 | Qinglong Spear Malus 5★ | #14 Malus at SL20 |
| W5 | Ewiyar's Beak 4★ | #16 Ewiyar's covenant as a sub |

### Water session
**Base** (10 weapons; it doesn't need to be a strong grid, only the same between captures):

| Slot | Weapon | State |
|---|---|---|
| MH | Hraesvelgr | 6★, transcendence 5 |
| | Leviathan Gaze Omega ×3 | 5★ |
| | Leviathan Gaze Mare ×3 | 4★ |
| | Staff of Repudiation | 6★, transcendence 5; β Pendulum + Pendulum of Extremity |
| | Doombringer Edge | 5★; Anklet of Oblivion |
| | *(test slot)* | |

**Summons:** Varuna 6★ T5 main; friend Varuna (any), and tell me which.

| Capture | Change | Answers |
|---|---|---|
| A0 | test slot empty | the base |
| A1 | Zodiaco Vitae 4★ (Clawed Flood, SL15) | #19 ATK Medium at SL15 |
| A2 | Xuanwu Mace Malus 5★ | #14 Malus at SL20 |
| A3 | Wamdus's Cnidocyte 4★ | #16 Azure Covenant as a sub |
| A4 | Hollowsky Staff 4★ | #16 Hollowsky covenant (Water) as a sub |

**Odious at 5★ (#17):** separately, main summon **Nihuyvintae 5★**, with four of your 0★ Water Odious weapons (Terrorbow of Mortality Verboten, exorcision 1) in place of the three Leviathan Gaze Mare and the test slot. Use a non-Odious friend summon. Expected header: Od 132% (3.0% × (40 + 4 levels)).

### Not possible yet
- **#20 Grace of Healing:** Asclepius Rod isn't in your collection.
- **#14 below SL20:** every Malus you own is 5★; a lower copy would add SL15/SL10 points later.

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

**From your collection:** all owned. Your Sword of Renunciation is transcendence 5 (the old capture had 3); use it and I'll adjust.

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

**From your collection:** Exo Hamartia (Special 10), Forsaken Agastia (yours is Attack lv1, not 20; fine, keep it), Cortana 3★, Advocatus Diaboli 5★, any Dark Bahamut Coda 5★, Trick Stick 3★. Pick any Malice, Epic, Regalia and Astral you own.

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

**From your collection:** Exo Hamartia (Attack 10), Fediel's Spine, Katana of Repudiation (Pendulum of Supremacy). Differences: you have one Covenant-Ruin Fist (not two); for the Armed Shadow weapon use Bismarck 5★; no Ultima has Gauph Key of Courage, so leave that slot to any Dark weapon and tell me which.

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

**From your collection:** all owned. The collection doesn't list your Spear of Renunciation's keys: check they're γ Pendulum + Chain of Restoration, or tell me what it has.

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

**From your collection:** all owned except the Voltage II daggers. Your Staff of Renunciation has β Pendulum + Chain of Falsehood, not Δ Pendulum, so the Δ lines won't appear; that's fine.

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

**From your collection:** Calamitous Aquashade 4★ (SL15), Varuna 6★ T5.

**Capture:** HP at 100%; note the in-game Max HP.

---

## Done

| # | Grid | Captured as | State |
|---|---|---|---|
| 1 | R1ckYi's design (Pendulum of Supremacy where R1ckYi had Sagacity) | LD66IX | every line matches; CI fixture |
| 3 | K4UydX's design | 7AiIOo | every line matches; CI fixture |
| 4 | SPhnLB's design | HDJE0N | every line matches; CI fixture |
| 7 | qBOvon's design | 0ZA6Ak, plus plktjH (no Mortality Bow Mk II) and k2hvSF (no Mortality Bow Mk II or Moros) | every line matches; CI fixtures |
| — | [Dark session](#dark-session) | LGZkRG, C1UGnK, GmPPWw, FaJB80 | CI fixtures; three EX Might lines open until the fallback fix |
| 5 | Dark Omega HP sweep (OlFQ2a's design, Pendulum of Supremacy in place of Chain of Falsehood) | XfBq6u, XfBq6u_hp75/50/25/1 | every line matches; 1% has Ω Enmity, DEF and the 0% C.A. DMG line open |
| 6 | Dark Optimus HP sweep (QJ9736's design) | nCvV1x (10 weapons, 100%); LqZ4tM_hp75/50/25/1 (13 weapons) | every line matches |
| 18 | Blazing Chain's supplement | WpPucd (Fire Omega) | every line matches; CI fixture. Also showed the panel counts the MC's own charge bar gain (Dainsleif) |
| — | Contributed Water Odious grid | XZq7xW | CI fixture; confirms Odious Exalto ("Water Taboo" 25, added to the Taboo enhancement). The Taboo header, the Od-amplified lines and the befoulment lines are open until the contributor's exorcision levels and befoulments are recorded |

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
