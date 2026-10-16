# Fallback-curve fix (Build::VERSION 9)

What the fallback-curve fix changes in the resolved weapon-skill data. Measured on `hensei_pipeline_fallback` (the pipeline database at Build::VERSION 8): the committed baseline, compared with the curation sync plus a full `build_weapon_skills all=true mode=write` on this branch. **286 versions change (297 rows); none is added or removed.** 254 rows change value and 43 rows are no longer generated. The user reviews every value change in this list before merge.

## What was wrong

A skill with no family of its own takes an SL curve from another family (`Registry#canonical_curve`). The old ranking put the sl15 value first, so the largest curve of the size won across every series. Since the Taboo family (×1.2) was added, EX skills with no family borrowed Taboo values: ATK Big 7.2/18/21.6, ATK Medium 3.6/14.4/17.4. Nothing in the game ties these skills to Odious.

## The new rule

- **Candidates:** only canonical curves of the tier (boost type, size, formula) in a series the skill can take: its own series, then `SERIES_FALLBACK` (normal → normal_omega, omega → normal_omega, odious ↔ taboo). EX has no fallback series, so an EX skill only takes EX curves. Odious/Taboo curves are never a fallback for a non-Odious skill.
- **Ranking:** the nearest series, then the boost type's base family (`Registry::BASE_FAMILIES`: Might for ATK, Aegis for HP, Trium for DA/TA, Verity, Enmity, Stamina, Healing), then completeness (more SL columns), then the modifier name and the row's values as a fixed key. The size of the values never decides. A new family can only move another skill's fallback if it shares that skill's series and is the base family, or ties the base family's absence on completeness and sorts first.
- **No compatible curve:** no row, and a build warning `no curve for <boost>/<size> in series "<series>" (<skill>)`.
- **Provenance:** each generated row copied from a fallback curve records it, as `provenance = "fallback:<modifier>/<series>"` (for example `fallback:Might/ex`). Parity ignores `provenance`, so this doesn't churn the baseline. The build summary now reports the count: **214 fallback rows**.

## The evidence

Base LGZkRG (EX Might 230, 230.5 internally); one weapon in the test slot:

| Capture | Weapon | Skill | Panel adds |
|---|---|---|---|
| C1UGnK | Bismarck 4★ | Armed Shadow, SL15 | 18 |
| FaJB80 | Bismarck 5★ | Armed Shadow, SL20 | 20 |
| GmPPWw | Qilin Sword 5★ | Clouds of Nightfall, SL20 | 21 |

Clarion's Armed Flood at SL20 with an Attack awakening lv15 reads 35 (20 + 15). The three EX Might lines were marked `skip` until this fix; they're checked now and pass.

## Changes by skill type

| Skill type | Versions | Old (SL1/10/15/20) | New | Evidence |
|---|---|---|---|---|
| **EX ATK Big, no family** | 92 | 7.2/18/21.6 (Tyranny, Taboo) | 6/15/18/21 (EX Might Big) | **Captured:** GmPPWw, Clouds of Nightfall at SL20 = 21. Template:Weapon Skills/Might, EX table. |
| **Armed Blaze/Flood/Gale/Grounds/Shadow/Shine** | 62 | 7.2/18/21.6 (Tyranny, Taboo) | 6/15/18/20 (new canonical **Armed** family) | **Captured:** C1UGnK (SL15 = 18), FaJB80 (SL20 = 20), Clarion's Armed Flood (SL20 + awakening 15 = 35). SL1/SL10 follow normal Might Big, by analogy only. The six skills now resolve through the family, so they no longer generate a row of their own. |
| **EX ATK Medium** ("Clawed …", Mysterious ATK, …) | 66 | 3.6/14.4/17.4 (Fandango, Taboo) | 3/12/14.5 (EX Might Medium) | **No capture.** Follows the canonical EX Might Medium row (Template:Weapon Skills/Might, EX table) without in-game confirmation. Captures are planned. |
| **EX HP Medium** ("Willed …", Mysterious VIT, Downfall of Ignorance) | 10 | 7.2/18/20.4 (Auspice, Taboo) | 3/12/14.5 (EX Aegis Medium) | **No capture.** Follows the canonical EX Aegis Medium row (Template:Weapon Skills/Aegis, EX table) without in-game confirmation. |
| **EX HP Big** ("Resilient …", Mysterious VIT II) | 10 | 9/18/21 (Aegis, normal) | 6/15/–/– (EX Aegis Big) | **No capture, incomplete source.** The stored Aegis template gives EX Big as 6/15/?/?; see "Stopped" below. |
| **EX HP Small: Tidings of the New World** (the five World weapons) | 5 | 3/12/14.5 (Aegis, omega) | 3/12/14.5/16, **curated** | SL15 = 14.5 is panel-confirmed by every golden with a World weapon (0ZA6Ak, plktjH, F0MD7j, ZCoUJT, HDJE0N, XZq7xW, lCMBmU, wOF5LS; all 4★). The curve is Template:Weapon Skills/True Supremacy's EX table, the same "Massive ATK / Small max HP" skill. **SL20 = 16 is from that template only.** |
| **EX HP Small: Mysterious VIT** (Mysterious Hatchet) | 1 | 3/12/14.5 (Aegis, omega) | 1/10/–/16 (EX Aegis Small) | **No capture, incomplete source.** See "Stopped". |
| **EX ATK Small** (All-Night Party, Speed Cast, Succession of Knighthood) | 3 | 1/10/12/13 (Might, normal) | 1/10/12 (EX Might Small) | **No capture.** Only SL20 changes: EX Might Small has no SL20 in the template. |
| **Normal/Omega ATK Big** (Inferno's Second Insignia; Ironflame's Gauntlet III) | 2 | 7.2/18/21.6 (Tyranny, Taboo) | 6/15/18/20 (Might normal / omega Big) | No capture. The skill's own series. |
| **Mountain's Enmity** (Fremel Hammer, normal) | 1 (2 rows) | ATK 3.6/14.4/17.4, HP 7.2/18/20.4 (Taboo) | ATK 3/12/14.5/16, HP 6/15/17 (Might / Aegis normal Medium) | No capture. The skill's own series. |
| **Terra's Third Spur** (Baihu Fangstaff, C.A. DMG Big, normal) | 1 | 5.5/10/12.5/14.5/16.5 (Glory, normal_omega) | 5.5/10/12.5 (Mystery, normal) | No capture. The exact series now beats normal_omega; SL1–15 are unchanged, SL20/25 are dropped. |
| **No row any more** | 43 | (various borrowed curves) | none, with a build warning | See below. |

### Rows no longer generated (43)

No canonical curve exists in the skill's series, so the build writes no row and warns. None of these is in a golden, and no stored template has a sized EX (or Odious) table for them: the Trium template has only "Normal & Omega" and "Taboo", Verity/Enmity/Healing/Stamina have no EX table. **These skills now add nothing in the calculator** until a capture or a cited curation gives their values.

| Group | Versions | Old (borrowed) |
|---|---|---|
| EX DA (Climate Control, Skull Parade, Synchronized Artistry ×3, Origin of All Zanpakuto, Noble's Dance, Ophidian Servitor, Royal Wing Barrier, Swiftblade Oath, Dexterity, Mifune Style: Binary Star, Solo) | 13 | Trium Taboo medium/small, Trium normal_omega big/massive |
| EX TA (Climate Control, Synchronized Artistry ×3, Origin of All Zanpakuto, Cuttlefish's Cut, Noble's Dance, Wild Wanderer, All-Night Party, Succession of Knighthood, Incantation Fang, Triple Talon Hellion) | 12 | same |
| EX Critical (Bang!, Spearsquid Flash, Twelfth Crown Prince's Favorite, Full-Auto Fire, Ghost on the Battlefield, Unblinking Stare, Piercing Fang, Pumpkin Trick) | 8 | Sephira Tek, Verity normal_omega, Precocity Taboo |
| EX Enmity (Golden Spirit, Undersky's Whispers, Audacity, Magic Charge, Firestorm's Enmity) | 5 | Bastion Odious, Enmity normal_omega |
| EX Heal cap (Grace of Healing, Grace of Healing II) | 2 | Sapience Taboo, Healing normal_omega |
| EX Stamina (Sunveil's Radiance) | 1 | Stamina omega Big (56.4) |
| Odious HP Small (Taboo Netherfell's Aegis) | 1 | Aegis omega Small |
| Odious Enmity Small (Taboo Doomfire's Enmity) | 1 | Enmity normal_omega Small |

**DA/TA have no canonical EX row.** They don't follow one: they get no row.

## Curation added (cited overlay entries)

| Entry | File | Values | Source |
|---|---|---|---|
| Canonical **Armed** (atk, EX, big) | `_canonical.json` | 6/15/18/20 | C1UGnK, FaJB80, Clarion's Armed Flood (above) |
| **Tidings of the New World** hp, 5 versions | `world.json` | 3/12/14.5/16 | Goldens with World weapons (SL15); Template:Weapon Skills/True Supremacy (curve, SL20) |
| **Eclipse's Stamina** (Fediel's Spine) stamina | `ancestral.json` | coefficient 50.4 (unchanged value) | XfBq6u and its HP sweeps: the two Spines give 44.84 of the Stamina line. Template:Weapon Skills/Stamina, Ancestral column, cited to Fediel's Spine. It used to borrow Stamina normal_omega Massive; without this entry XfBq6u's four Stamina lines fail. |
| **Authority's Trium** (Lu Woh's Horn) da and ta | `ancestral.json` | 2.8/10/14 (unchanged value) | Template:Weapon Skills/Trium, Massive row, cited to GameWith, Lu Woh's Horn. |

The citation sits in each row's `provenance` (data rows have no notes column).

## Stopped for lack of stored evidence

- **EX Aegis Small** (Template:Weapon Skills/Aegis, EX table): 1/10/**?**/16, cited to Kamigame. SL15 isn't stored. The row stays as is; Mysterious VIT (Mysterious Hatchet) now reads it. Tidings would have too, which is how an earlier series-first attempt broke 5 references; it's curated instead (above).
- **EX Aegis Big**: 6/15/**?/?**. SL15 and SL20 aren't stored. Resilient … and Mysterious VIT II now read it.
- **EX Aegis Medium**: 3/12/14.5/**?**. SL20 isn't stored; the calculator holds 14.5.
- **EX DA/TA, Critical, Enmity, Heal cap, Stamina by size**: no stored template has these tables (above).

Each needs a capture or the Kamigame page (not stored; never fetched).

## Goldens

- **C1UGnK, FaJB80, GmPPWw:** the EX Might lines are checked again (no `skip`) and match; their fixtures are re-exported from this database. The re-export also carries this database's catalogue state for those three parties (skill-label positions, two new labels, the anklet key effects), which no line depends on.
- **The World-weapon goldens** (0ZA6Ak, plktjH, F0MD7j, ZCoUJT, HDJE0N, XZq7xW, lCMBmU, wOF5LS) keep HP: Tidings is curated.
- **XfBq6u** (and its sweeps) keeps Stamina: Eclipse's Stamina is curated.
- No other reference moved. `granblue:validate_panel` on the rebuilt database: every fixture party matches; `spec/requests/goldens_spec.rb`: 84 examples, 0 failures.

## Checks

On `hensei_pipeline_fallback`, after `sync_weapon_skill_curation` (the registry reads canonical rows from the database, so the Armed row must be synced before the build; the deploy does this in `db:migrate:with_data`):
- the first full write: rows ~214 updated (provenance), −108 deleted (62 Armed versions now covered by the family; 46 with no compatible curve, of which Authority's Trium's two rows and Eclipse's Stamina were then restored by curation), versions ~12 (the 12 Armed versions added from the expanded page now carry the Armed modifier);
- two further full builds in a row: `versions +0 ~0 -0; rows +0 ~0 -0`;
- `granblue:skill_parity`: no differences against the refreshed baseline;
- the curation drift check is clean, and a re-export leaves the new entries byte-identical.

## Follow-ups (not in this change)

- `WeaponSkillDatum.canonical_curve` (the model, used by `KeySkillExtractor`) still ranks by sl15 first.
- `Registry#for_skill` still uses sl15 as a tie-break within one family.

## Every changed version

### atk big (ex): 7.2/18/21.6 → 6/15/18/21 — 92

21 Excellent-Grade Sword (Wado Ichimonji, `1040914100` slot 0); A Pro's Tool (Soldier Bow, `1040709700` slot 0); A Thousand Dreams (Red Cyclone, `1040015500` slot 0); Air Blast (Air Cannon, `1040615600` slot 0); Amethyst's Splendor (Sharom Bow, `1040708100` slot 1); Anti-Cursed Spirit Weaponry (Slaughter Demon, `1040117100` slot 0); Apex Predator (Shock-a-Lot, `1040211300` slot 0); Architect ATK Ⅱ (Architect Frame, `1040413300` slot 1); Asuna's Artifact (Ensis Exorcizans, `1040028300` slot 0); Auto Apparatus (Blast Sword, `1040006000` slot 0); Best Friends (Vyrn Star Sword, `1030005000` slot 0); Blood Drip (Chop-Chop, `1040110900` slot 0); Bloodthirsty Deities (Khopesh, `1040019000` slot 0); Boulder Breaker (Ko-Focused Fist, `1040620900` slot 0); Breath of Mysteria (Mysterian Holy Scepter, `1040411400` slot 1); Clouds of Nightfall (Qilin Sword, `1040010000` slot 0); Cursed Tentacle (Blade of the Scourged, `1040009500` slot 1); Darkness Concealer (Sealing Staff, `1040412800` slot 0); Devicer (V.A.R.I.S., `1040511300` slot 0); Divine Gavel (Staff of Divine Justice, `1040414500` slot 0); Doc Agasa's Invention (Kicking Enhancement Shoes, `1040610100` slot 0); Dragonstrike's Wisdom (Wyrmsword, `1040014100` slot 1); Ebony Blade (Nichirin Sword, `1040912700` slot 0); Explosive Reinforcement (Bakugo's Bracers, `1040618300` slot 0); Fleeting Wisps (Holy Fox Strings, `1040810000` slot 0); Flesh Ripper (Snap Blade, `1040014200` slot 0); Fluffy-Wuffy Tail (Cat's Tail, `1040414800` slot 0); Focus Attack (Street Weapon, `1040603100` slot 1); Foxflame's Flicker (Martial Steel of the Sovereign, `1040908500` slot 1); Frozen Blade (Ice Claymore, `1040016200` slot 0); Full-Auto Fire (Assault Rifle (Man-Portable), `1040518700` slot 0); Fullmetal Right Arm (Automail Arm, `1040621600` slot 0); Good and Tasty (Golden Bell, `1040808800` slot 0); Gourmet Banana (Banana Bunch, `1040309700` slot 0); Grace of the Omnilight (Blade of Light, `1040005900` slot 0); Grand Works (Nigredo Lance, `1040208000` slot 1); Great Sword Under Heaven (Mikazuki Munechika, `1040908200` slot 0); Heaven's Truth (Glory Thread, `1040015100` slot 0); Heavy-Metal Body (Mega Metallic Yo-Yo, `1040319500` slot 0); Hell Mode (Magic Sword Tenma, `1040027700` slot 0); Intelligence (Guivre Rod, `1040408500` slot 0); Layman's Saw of Death (Machine Saw, `1040313800` slot 0); Let's Play (Luna's Friend, `1040409300` slot 0); Lion and Cow's Call (Cherubim's Lance, `1040212400` slot 0); Magical Activation Item (Negi's Staff, `1040424000` slot 0); Mifune Style, Zen Impact (Red Sun, `1040905600` slot 0); My Words for You (Dandelion, `1040108800` slot 1); Mysterious ATK II (Mysterious Sword, `1040003300` slot 0); Mysterious ATK II (Pina Colata Cleaver, `1040103900` slot 0); Mysterious ATK II (Pink Fan, `1040607300` slot 0); Mysterious ATK II (Piña Bestiary, `1040417000` slot 0); Mysterious ATK II (Sombre Axe, `1040305400` slot 0); Mysterious ATK II (Swirly Wurst Hammer, `1040306000` slot 0); Nameless Zanpakuto (Asauchi, `1040918800` slot 0); Old Man Zangetsu (Zangetsu, `1040918700` slot 0); One Light (Love Live Light, `1040111500` slot 0); Point and Shoot (Compound Gadget Bow, `1040705500` slot 1); Power Conduit (Meteor's Light, `1040510400` slot 0); Power of the Prism Stones (Rainbow Bracelet, `1040610800` slot 0); Powerbomb (True Grit, `1040611400` slot 0); Rachis of Fire (Souval Gauntlet, `1040606200` slot 1); Rindo Emblem (Tsurumaru Kuninaga, `1040908300` slot 0); Royal Affection (Queen's Stinger, `1040108900` slot 1); School Idol (Rin's Maracas, `1040611900` slot 0); Schoolmates (Schoolbag, `1040309900` slot 0); Search for Enlightenment (Bell Striker, `1040309200` slot 1); Self-taught Swordsmanship (Fugudoku, `1040906000` slot 0); Sentient Simulacrum (Edem, `1040217200` slot 0); Shadowverse Player (Shadowverse Gauntlet, `1040614200` slot 0); Shark Attack! (Shark Bite, `1040310900` slot 0); Sign from Above (Dominion Harp, `1040805600` slot 1); Spear of Despair (Spear of Longinus (Man-Portable), `1040220600` slot 0); Spirit Serenity (Raphael, `1040505700` slot 0); Squad Goals (Aluminum Bat, `1040015900` slot 0); Strength (Balanced Blade, `1040004500` slot 0); Strength (Gauntlets, `1040602800` slot 0); Strength (Second Star, `1040902200` slot 0); Sunshiner (Sunshine Blade, `1040110800` slot 0); Suono Forte (Renaissance Harp, `1040808600` slot 0); Super Abomideath Power Z (Emperor's Hand, `1040610500` slot 0); Tempest's Vestige (Ishkur Shaft, `1040019200` slot 0); The Phantom (God of a Thousand Demons, `1040509500` slot 0); Thunder of the Sunrise (Huanglong Gauntlet, `1040607100` slot 0); Tube Feet (Urchin Fist, `1040608700` slot 1); Up in Arms (Kraken Club, `1040420300` slot 0); V-Skill (Poison Hand, `1040605500` slot 0); Warrior's Assault (Glaive of Exultation, `1040214600` slot 0); Weather Controller (Sorcery Climate Baton, `1040420900` slot 0); Weaver Stance (Compact Automatic Pistol, `1040509300` slot 0); Westerly Rhapsody (Harp of Westerly Winds, `1040805300` slot 1); What Happens 2x, Happens 3x (Wooden Sword Lake Toya, `1040913200` slot 0); Xingese Blade (Xingese Liuyedao, `1040918500` slot 0)

### atk medium (ex): 3.6/14.4/17.4 → 3/12/14.5 — 66

Clawed Blaze (Astro Wand, `1030406200` slot 0); Clawed Blaze (Brennuglofi, `1030609900` slot 0); Clawed Blaze (Butler's Glove, `1030609600` slot 0); Clawed Blaze (Disaster Bolt, `1030506100` slot 0); Clawed Blaze (Fire Starter, `1030108900` slot 0); Clawed Blaze (Mindfade Edge, `1030903900` slot 0); Clawed Blaze (Opening Shamisen, `1030804700` slot 0); Clawed Blaze (Scorched Scorn, `1040619200` slot 0); Clawed Blaze (Scorching Fan, `1030305700` slot 0); Clawed Blaze (Vocazione, `1030406700` slot 0); Clawed Blaze (Zombie Hunter, `1030009700` slot 0); Clawed Flood (Death Whip, `1030009900` slot 0); Clawed Flood (Kombu Dashi, `1030305800` slot 0); Clawed Flood (Rising Rebellion, `1030010100` slot 0); Clawed Flood (Second Serving, `1030609100` slot 0); Clawed Flood (Zodiaco Vitae, `1040115100` slot 1); Clawed Gale (Alster Spear, `1030207800` slot 0); Clawed Gale (Chivalrous Spear, `1030207900` slot 0); Clawed Gale (Col du Chat, `1030704600` slot 0); Clawed Gale (Gauntlet of Bewilderment, `1030610000` slot 0); Clawed Gale (Griffith Bow, `1030704800` slot 0); Clawed Gale (Pathos Cantabile, `1030208100` slot 0); Clawed Gale (Skeeter Beater, `1030010600` slot 0); Clawed Gale (Stand-Up Mic, `1030406600` slot 0); Clawed Grounds (Bombyx Bow, `1030704700` slot 0); Clawed Grounds (Dandy Fist, `1030609400` slot 0); Clawed Grounds (Dum Edabl, `1030903700` slot 0); Clawed Grounds (Halite Axe, `1030306000` slot 0); Clawed Grounds (Indestructible Plume, `1030109300` slot 0); Clawed Grounds (Lost Claymore, `1030010200` slot 0); Clawed Grounds (Nimuean Drachenstock, `1030406500` slot 0); Clawed Grounds (Plagueborne Spear, `1030208200` slot 0); Clawed Grounds (Stone Ilhoon, `1030010400` slot 0); Clawed Grounds (Tracker's Gauntlet, `1030609700` slot 0); Clawed Shadow (Baguette Magique, `1030208000` slot 0); Clawed Shadow (Beak Slasher, `1030010500` slot 0); Clawed Shadow (Black Lion's Tail, `1030009800` slot 0); Clawed Shadow (Corn Slicer, `1030010300` slot 0); Clawed Shadow (Henchman, `1030109100` slot 0); Clawed Shadow (Kahuan Pahoa, `1030109500` slot 0); Clawed Shadow (Nightfall's Wing, `1030109400` slot 0); Clawed Shadow (Rhothion Harp, `1030804600` slot 0); Clawed Shadow (Storyteller's Strings, `1030804300` slot 0); Clawed Shadow (Sword of Empowerment, `1030010000` slot 0); Clawed Shadow (T. Axe, `1030305900` slot 0); Clawed Shadow (Umbral Blade, `1030903800` slot 0); Clawed Shadow (Waldharfe, `1030804400` slot 0); Clawed Shadow (Wrathful Resentment, `1030804500` slot 0); Clawed Shine (
Klesha-Cleansing Dharmachakra, `1030609800` slot 0); Clawed Shine (Bedazzled Dagger, `1030109000` slot 0); Clawed Shine (CtK4Life Merch Sample, `1030609000` slot 0); Clawed Shine (Orichalcum Claw, `1030610100` slot 0); Clawed Shine (Preghiera, `1030406400` slot 0); Downfall of Ignorance (Iridescent Bow, `1040709400` slot 1); Hijikata Edge (Izuminokami Kanesada, `1030902600` slot 0); Kunihiro Masterpiece (Yamanbagiri Kunihiro, `1030902700` slot 0); Mysterious ATK (Mysterious Glove, `1030603300` slot 0); Mysterious ATK (Mysterious Hatchet, `1040303100` slot 0); Mysterious ATK (Mysterious Shooter, `1030502800` slot 0); Mysterious ATK (Pina Colata Pistol, `1030503200` slot 0); Mysterious ATK (Pink Magazine, `1030404800` slot 0); Mysterious ATK (Sombre Knife, `1030104600` slot 0); Nature's Providence (Chichiushi, `1040906100` slot 0); On the Offensive (Salad Tongs, `1030605300` slot 0); Ryoma's Trusty Sword (Mutsunokami Yoshiyuki, `1030902500` slot 0); Treasured Blade of Ashikaga (Honebami Toushirou, `1030902400` slot 0)

### atk big (ex): 7.2/18/21.6 → 6/15/18/20 — 62

Armed Blaze (Astro Modele, `1040514900` slot 0); Armed Blaze (Blade of Calamity's Bane, `1040029100` slot 0); Armed Blaze (Clucky Lantern, `1040315200` slot 0); Armed Blaze (Czar's Belchzooka, `1040516000` slot 0); Armed Blaze (Disaster Claw, `1040616400` slot 0); Armed Blaze (Grim Evidence, `1040117900` slot 0); Armed Blaze (Marquesas, `1040617100` slot 2); Armed Blaze (Protean Folding Fan, `1040619900` slot 0); Armed Blaze (Resentment's Gaze, `1040712000` slot 0); Armed Blaze (Rocket Launcher, `1040514700` slot 0); Armed Blaze (Steelflame Hornaxe, `1040320200` slot 0); Armed Blaze (Thorned Axe of Roses and Blood, `1040319300` slot 0); Armed Blaze (Ushumgal, `1040016100` slot 2); Armed Flood (Aburaboshi Ramen Flag, `1040217000` slot 0); Armed Flood (Anti-Asteroid Beam Cannon, `1040519100` slot 0); Armed Flood (Bident, `1040213800` slot 2); Armed Flood (Chained Bow of Hell and Heaven, `1040712700` slot 0); Armed Flood (Clarion, `1040511200` slot 2); Armed Flood (Hand Cannon, `1040515500` slot 0); Armed Flood (King's Thruster, `1040617600` slot 0); Armed Flood (Shark Breath, `1040714500` slot 0); Armed Flood (Skeleton Cane, `1040420200` slot 0); Armed Gale (Blade of Remorse, `1040028700` slot 0); Armed Gale (Bloodsucker Blade, `1040918600` slot 0); Armed Gale (Chivalrous Blade, `1040023000` slot 0); Armed Gale (Chromatic Paintbrush, `1040122500` slot 0); Armed Gale (Daur da Blao, `1040813900` slot 2); Armed Gale (Dent du Chat, `1040023800` slot 0); Armed Gale (Foil's Foiler, `1040317100` slot 0); Armed Gale (Windhose, `1040016500` slot 2); Armed Grounds (Agarthan Hunter's Dagger, `1040120900` slot 0); Armed Grounds (Chronicler's Federhalter, `1040117300` slot 0); Armed Grounds (Cursed Staff of Calamity, `1040422800` slot 0); Armed Grounds (Daggerpeak, `1040215000` slot 2); Armed Grounds (Dawn Rising, `1040416500` slot 2); Armed Grounds (Dum Ethysc, `1040314800` slot 0); Armed Grounds (Lil' Macho, `1040024400` slot 0); Armed Grounds (Referee's Gunbai, `1040119800` slot 0); Armed Grounds (Scorn of the Goblin King, `1040219600` slot 0); Armed Shadow (Albacore Body, `1040423500` slot 0); Armed Shadow (Autumn's Decline, `1040914200` slot 0); Armed Shadow (Bismarck, `1040514500` slot 2); Armed Shadow (Black Lion's Fang, `1040314400` slot 0); Armed Shadow (Bow of Phantasmic Obsession, `1040712200` slot 0); Armed Shadow (Caliginous Quill, `1040220400` slot 0); Armed Shadow (Daemonenschwinge, `1040712500` slot 0); Armed Shadow (Hollow Purity, `1040915700` slot 0); Armed Shadow (Kahuan Pololu Kahiko, `1040221200` slot 0); Armed Shadow (Mother's Mad Spine, `1040025500` slot 0); Armed Shadow (Scarface, `1040517300` slot 0); Armed Shadow (Sword of Gratitude, `1040116300` slot 0); Armed Shadow (Tigerclaw, `1040026200` slot 0); Armed Shadow (Zwei Schaedel, `1040612200` slot 2); Armed Shine (Autograph Art Sketchbook, `1040419200` slot 0); Armed Shine (Bane of Avidya, `1040424100` slot 0); Armed Shine (Blarthor, `1040220000` slot 0); Armed Shine (Dawnstar Weaver, `1040425900` slot 0); Armed Shine (Gusisnautar, `1040713300` slot 2); Armed Shine (Phantom Fangs, `1040614500` slot 2); Armed Shine (Precipian Staff, `1040425200` slot 0); Armed Shine (Prodigious Tome of Crimson, `1040426500` slot 0); Armed Shine (Ravenous Wingbow, `1040715100` slot 0)

### hp big (ex): 9/18/21 → 6/15 — 10

Mysterious VIT II (Mysterious Wand, `1040401600` slot 0); Resilient Flood (Materpent Lyre, `1040818300` slot 0); Resilient Gale (Alster Bow, `1040711300` slot 0); Resilient Gale (Intervallo Bramoso, `1040421700` slot 0); Resilient Gale (Le Chevalier au Lion, `1040026800` slot 0); Resilient Grounds (Seaside Guardian, `1040621900` slot 0); Resilient Shadow (Giant Octo Leg on a Stick, `1040220200` slot 0); Resilient Shadow (Pantoufle de Machine, `1040316000` slot 0); Resilient Shadow (Shuprae Specialty, `1040619400` slot 0); Resilient Shine (Frilly Charm Bracelet, `1040618700` slot 0)

### hp medium (ex): 7.2/18/20.4 → 3/12/14.5 — 10

Downfall of Ignorance (Iridescent Bow, `1040709400` slot 1); Mysterious VIT (Mysterious Harp, `1030801100` slot 0); Mysterious VIT (Pina Colata Bow, `1030702900` slot 0); Mysterious VIT (Tadpole Tail, `1030104200` slot 0); Willed Blaze (Miner's Lantern, `1030306100` slot 0); Willed Blaze (Trap Knight's Helm, `1030609500` slot 0); Willed Flood (Motherly Flower Wreath, `1030704900` slot 0); Willed Flood (Shark Bouquet, `1030109200` slot 0); Willed Gale (Achromatic Palette, `1030406800` slot 0); Willed Grounds (Beach Flag, `1030109600` slot 0)

### da medium (ex): 1/4.2/6 → (no row) — 6

Climate Control (Ishkur Shaft, `1040019200` slot 1); Skull Parade (Skull Wand, `1030401800` slot 0); Synchronized Artistry (Anti-Asteroid Beam Cannon, `1040519100` slot 1); Synchronized Artistry (Materpent Lyre, `1040818300` slot 1); Synchronized Artistry (Seaside Guardian, `1040621900` slot 1); The Origin of All Zanpakuto (Asauchi, `1040918800` slot 1)

### hp small (ex): 3/12/14.5 → 3/12/14.5/16 — 5

Tidings of the New World (Worldbreaking Tauros, `1040815300` slot 0); Tidings of the New World (Worldforging Moros, `1040815000` slot 0); Tidings of the New World (Worldscathing Leon, `1040815100` slot 0); Tidings of the New World (Worldstorming Aetos, `1040815200` slot 0); Tidings of the New World (Worldvexing Angelos, `1040815400` slot 0)

### ta medium (ex): 1/4.2/6 → (no row) — 5

Climate Control (Ishkur Shaft, `1040019200` slot 1); Synchronized Artistry (Anti-Asteroid Beam Cannon, `1040519100` slot 1); Synchronized Artistry (Materpent Lyre, `1040818300` slot 1); Synchronized Artistry (Seaside Guardian, `1040621900` slot 1); The Origin of All Zanpakuto (Asauchi, `1040918800` slot 1)

### da massive (ex): 2.8/10/14 → (no row) — 4

Noble's Dance (Luin, `1040203900` slot 2); Ophidian Servitor (Ouroboros, `1040401100` slot 1); Royal Wing Barrier (Pilum, `1040200200` slot 1); Swiftblade Oath (Hoarfrost Blade Persius, `1040102100` slot 1)

### atk small (ex): 1/10/12/13 → 1/10/12 — 3

All-Night Party (Spirit Seeker, `1040311400` slot 1); Speed Cast (Fonic Rod, `1040408400` slot 1); Succession of Knighthood (Brand of Binding Oath, `1040019400` slot 1)

### critical big (ex): 4.4/8/10/11 → (no row) — 3

Full-Auto Fire (Assault Rifle (Man-Portable), `1040518700` slot 0); Ghost on the Battlefield (Soldier Bow, `1040709700` slot 1); Unblinking Stare (Revolvyrn, `1030504300` slot 0)

### critical massive (ex): 2/20/30 → (no row) — 3

Bang! (Air Cannon, `1040615600` slot 1); Spearsquid Flash (Squidpiercer, `1030204100` slot 0); Twelfth Crown Prince's Favorite (Xingese Liuyedao, `1040918500` slot 1)

### ta massive (ex): 2.8/10/14 → (no row) — 3

Cuttlefish's Cut (Squid Hand, `1030601300` slot 0); Noble's Dance (Luin, `1040203900` slot 2); Wild Wanderer (Vassago, `1040301200` slot 1)

### critical medium (ex): 3.8/6/7.8 → (no row) — 2

Piercing Fang (Brionac, `1040200300` slot 2); Pumpkin Trick (Lantern Blade, `1030003100` slot 0)

### da small (ex): 0.3/3/4.2 → (no row) — 2

Dexterity (Guivre Rod, `1040408500` slot 1); Mifune Style, Binary Star (Red Sun, `1040905600` slot 1)

### enmity big (ex): -/12/15 → (no row) — 2

Golden Spirit (Edem, `1040217200` slot 1); Undersky's Whispers (Advocatus Diaboli, `1040213300` slot 1)

### ta big (ex): 1.2/5/7 → (no row) — 2

Incantation Fang (Medusiana Staff, `1040414000` slot 1); Triple Talon Hellion (Coco & Mimi, `1040600600` slot 1)

### ta small (ex): 0.3/3/4.2 → (no row) — 2

All-Night Party (Spirit Seeker, `1040311400` slot 1); Succession of Knighthood (Brand of Binding Oath, `1040019400` slot 1)

### atk big (normal): 7.2/18/21.6 → 6/15/18/20 — 1

Inferno's Second Insignia (Zhuque Lyrewings, `1040805100` slot 0)

### atk big (omega): 7.2/18/21.6 → 6/15/18/20 — 1

Ironflame's Gauntlet III (Hand of Brahman, `1040609800` slot 0)

### atk medium (normal): 3.6/14.4/17.4 → 3/12/14.5/16 — 1

Mountain's Enmity (Fremel Hammer, `1030303700` slot 0)

### ca_dmg big (normal): 5.5/10/12.5/14.5/16.5 → 5.5/10/12.5 — 1

Terra's Third Spur (Baihu Fangstaff, `1040408600` slot 0)

### da big (ex): 1.2/5/7 → (no row) — 1

Solo (Vyrnstrument, `1030802900` slot 0)

### enmity massive (ex): -/-/18.75 → (no row) — 1

Firestorm's Enmity (Wilnas's Finger, `1040613800` slot 0)

### enmity medium (ex): 0.66/8/10 → (no row) — 1

Magic Charge (Fonic Rod, `1040408400` slot 0)

### enmity small (ex): 0.5/6/7/7.5 → (no row) — 1

Audacity (Thunder Dirk Jove, `1040101800` slot 1)

### enmity small (odious): 0.5/6/7/7.5 → (no row) — 1

Taboo Doomfire's Enmity (Karmasword of Prosperity Verboten, `1040029800` slot 1)

### heal_cap big (ex): 5/10/15/17.5 → (no row) — 1

Grace of Healing II (Asclepius Rod, `1040400300` slot 0)

### heal_cap small (ex): 1.2/6/9 → (no row) — 1

Grace of Healing (Asclepius Rod, `1040400300` slot 0)

### hp medium (normal): 7.2/18/20.4 → 6/15/17 — 1

Mountain's Enmity (Fremel Hammer, `1030303700` slot 0)

### hp small (ex): 3/12/14.5 → 1/10/-/16 — 1

Mysterious VIT (Mysterious Hatchet, `1040303100` slot 1)

### hp small (odious): 3/12/14.5 → (no row) — 1

Taboo Netherfell's Aegis (Codex of Sanctity Verboten, `1040426200` slot 1)

### stamina big (ex): stamina coefficient 56.4 → (no row) — 1

Sunveil's Radiance (True Purity Sunblade, `1040015400` slot 1)
