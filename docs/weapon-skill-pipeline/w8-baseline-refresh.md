# W8 baseline refresh

What changes when the weapon-skill build replaces the old writers (W8, #561). Measured on `catalogue-20261015-prod` with every pending migration applied: the database before the build against the database after `granblue:build_weapon_skills all=true mode=write` and the curation sync.

**77 changed, 2 removed, 30 added versions.** Every one is classified `intended` with a cited source in `data/weapon_skill_parity/w8/*.json` (the full reason and source for each key are there).

Not in this table, because the parity snapshot doesn't compare them (resolved values are unaffected):

- `scales_with_skill_level` changes on 270 versions, mostly true → false on unique skills the old importers left at the column default. Nothing reads it except the API blueprint.
- 63 versions with an overlay family override store a different *derived* `skill_modifier` (the backfill's, often blank instead of the old name-parser family). The calculator reads the override.
- Earlier today on prod, before the build: 12 junk `}}} Enforcement` versions are removed by the curation sync (`remove_version` ops in `revans.json`), and Regus and Subekuri Gauntlet gained 6 versions.

## By series

### gacha (39)

| Version | Change | Why |
|---|---|---|
| 1030902200 \| 0 \| 0 \| Mountain's Aegis | added | Tyrian Tiger Blade: Stored wikitext has `s1_name`/`s1_desc`; the weapon had no skills in the DB at all (never persisted). gbf.wiki weapon page, skill 1. The build creates it from the page. |
| 1040016000 \| 2 \| 0 \| Aquae Excelsior | changed: frame | Gottfried: gbf.wiki Template:Weapon_Skills/Excelsior: "Unboostable", one tier (5.5/10/15), no size. Size `big` was left by the retired icon derivation (0248b08f). Data unchanged: canonical Excelsior row is sizeless. |
| 1040020400 \| 1 \| 0 \| Luminis Excelsior | changed: frame | Official's Jitte: gbf.wiki Template:Weapon_Skills/Excelsior: "Unboostable", one tier (5.5/10/15), no size. Size `big` was left by the retired icon derivation (0248b08f). Data unchanged: canonical Excelsior row is size… |
| 1040021000 \| 2 \| 0 \| Terrae Excelsior | changed: frame | Lovely Ace: gbf.wiki Template:Weapon_Skills/Excelsior: "Unboostable", one tier (5.5/10/15), no size. Size `big` was left by the retired icon derivation (0248b08f). Data unchanged: canonical Excelsior row is sizeless. |
| 1040022800 \| 2 \| 0 \| Arsus Excelsior | changed: frame | Arcane Rouge: gbf.wiki Template:Weapon_Skills/Excelsior: "Unboostable", one tier (5.5/10/15), no size. Size `big` was left by the retired icon derivation (0248b08f). Data unchanged: canonical Excelsior row is sizeless. |
| 1040027800 \| 2 \| 0 \| Caliginis Excelsior | changed: frame | Goriki-maru Revised: gbf.wiki Template:Weapon_Skills/Excelsior: "Unboostable", one tier (5.5/10/15), no size. Size `big` was left by the retired icon derivation (0248b08f). Data unchanged: canonical Excelsior row is s… |
| 1040111100 \| 1 \| 0 \| Caliginis Excelsior | changed: frame | Gandring: gbf.wiki Template:Weapon_Skills/Excelsior: "Unboostable", one tier (5.5/10/15), no size. Size `big` was left by the retired icon derivation (0248b08f). Data unchanged: canonical Excelsior row is sizeless. |
| 1040115200 \| 2 \| 0 \| Coeli Excelsior | changed: frame | Bon Joie: gbf.wiki Template:Weapon_Skills/Excelsior: "Unboostable", one tier (5.5/10/15), no size. Size `big` was left by the retired icon derivation (0248b08f). Data unchanged: canonical Excelsior row is sizeless. |
| 1040115300 \| 1 \| 0 \| Arsus Excelsior | changed: frame | War Fan of Secret Teachings: gbf.wiki Template:Weapon_Skills/Excelsior: "Unboostable", one tier (5.5/10/15), no size. Size `big` was left by the retired icon derivation (0248b08f). Data unchanged: canonical Excelsior … |
| 1040210600 \| 1 \| 0 \| Bountiful Strike | changed: data, frame | Cherished Flip Charm: Tail-word false join. Page: MC-only Bonus Light DMG vs Bounty. gbf.wiki Template:Weapon_Skills/Strike is N.A. DMG cap; that row was a phantom. The dropped rows are the phantom family rows w2-clas… |
| 1040216100 \| 1 \| 0 \| Arsus Excelsior | changed: frame | Flamelance: Accendo: gbf.wiki Template:Weapon_Skills/Excelsior: "Unboostable", one tier (5.5/10/15), no size. Size `big` was left by the retired icon derivation (0248b08f). Data unchanged: canonical Excelsior row is s… |
| 1040217200 \| 0 \| 0 \| Sentient Simulacrum | changed: frame | Size nil -> big: the size now follows the skill description. 'Edem' starts with an {{About}} hatnote, so the old parser followed it to a missing page and never parsed it; the stored size predates today's parser. The b… |
| 1040217200 \| 1 \| 0 \| Golden Spirit | changed: frame | Size nil -> big: the size now follows the skill description. 'Edem' starts with an {{About}} hatnote, so the old parser followed it to a missing page and never parsed it; the stored size predates today's parser. The b… |
| 1040313300 \| 1 \| 0 \| Bitter Perseverance | changed: frame | Dalmoran Battle Axe: Unique MC-only skill (15% charge gain, kept as linked row); no 'Perseverance' family. Link was inert. |
| 1040317000 \| 1 \| 0 \| Caliginis Excelsior | changed: frame | Buddysaurus Rex: gbf.wiki Template:Weapon_Skills/Excelsior: "Unboostable", one tier (5.5/10/15), no size. Size `big` was left by the retired icon derivation (0248b08f). Data unchanged: canonical Excelsior row is sizel… |
| 1040401100 \| 1 \| 0 \| Ophidian Servitor | changed: frame | Size nil -> massive: the size now follows the skill description. 'Ouroboros' starts with an {{About}} hatnote, so the old parser followed it to a missing page and never parsed it; the stored size predates today's pars… |
| 1040403900 \| 0 \| 0 \| Bells of Grace | changed: frame | Gotle Bell Cane: Page: 5% EXP boost. gbf.wiki Template:Weapon_Skills/Grace is max HP + debuff res. Link was inert (no rows). |
| 1040408400 \| 0 \| 0 \| Magic Charge | changed: effects, frame | Fonic Rod: Page: 'Medium boost to light allies' ATK based on how low HP is', icon `ws_skill_backwater_5_2` = enmity (kept as linked row). gbf.wiki Template:Weapon_Skills/Charge is C.A. per grid; those effects were pha… |
| 1040413300 \| 0 \| 0 \| Architect Battle Arts | changed: data, frame | Architect Frame: Page: MC-only chance of a random buff. gbf.wiki Template:Weapon_Skills/Arts is skill DMG cap; that row was a phantom. The dropped rows are the phantom family rows w2-classification.md lists under "Row… |
| 1040423800 \| 2 \| 0 \| Glimmer's Crux | changed: frame | Equilibrium Tannenwand: gbf.wiki Template:Weapon_Skills/Crux, section "Unboostable Crux": no size (only Boostable Normal/Taboo are Big). Data unchanged: `Crux\\|ca_supp\\|ex\\|big` is the only EX row and resolves with… |
| 1040508800 \| 2 \| 0 \| Luminis Excelsior | changed: frame | Ruler of Fate: gbf.wiki Template:Weapon_Skills/Excelsior: "Unboostable", one tier (5.5/10/15), no size. Size `big` was left by the retired icon derivation (0248b08f). Data unchanged: canonical Excelsior row is sizeless. |
| 1040509400 \| 1 \| 0 \| Tsunami's Might | added | White Hawk's page puts \|s2_name=Tsunami's Might on its s1_desc line; MediaWiki ends a parameter at the first top-level pipe, so s2 exists. The line-based parser missed it; Structure::Wikitext now splits there. |
| 1040512000 \| 1 \| 0 \| Excess Voltage | changed: effects, frame | Plasma Ripper: Page: MC-only stackable DA/TA buff. gbf.wiki Template:Weapon_Skills/Voltage is per-weapon-type EX Might Sp.; that row was a phantom. The dropped rows are the phantom family rows w2-classification.md lis… |
| 1040512500 \| 2 \| 0 \| Aquae Excelsior | changed: frame | Acid Bolt Shooter: gbf.wiki Template:Weapon_Skills/Excelsior: "Unboostable", one tier (5.5/10/15), no size. Size `big` was left by the retired icon derivation (0248b08f). Data unchanged: canonical Excelsior row is siz… |
| 1040513200 \| 2 \| 0 \| Arsus Excelsior | changed: frame | Mystic Spray Gun: gbf.wiki Template:Weapon_Skills/Excelsior: "Unboostable", one tier (5.5/10/15), no size. Size `big` was left by the retired icon derivation (0248b08f). Data unchanged: canonical Excelsior row is size… |
| 1040513600 \| 1 \| 0 \| Terrae Excelsior | changed: frame | Beach-Camouflage Vlisragna: gbf.wiki Template:Weapon_Skills/Excelsior: "Unboostable", one tier (5.5/10/15), no size. Size `big` was left by the retired icon derivation (0248b08f). Data unchanged: canonical Excelsior r… |
| 1040514400 \| 2 \| 0 \| Aquae Excelsior | changed: frame | Plasma Slicer: gbf.wiki Template:Weapon_Skills/Excelsior: "Unboostable", one tier (5.5/10/15), no size. Size `big` was left by the retired icon derivation (0248b08f). Data unchanged: canonical Excelsior row is sizeless. |
| 1040514600 \| 2 \| 0 \| Terrae Excelsior | changed: frame | Bubble Sketcher: gbf.wiki Template:Weapon_Skills/Excelsior: "Unboostable", one tier (5.5/10/15), no size. Size `big` was left by the retired icon derivation (0248b08f). Data unchanged: canonical Excelsior row is sizel… |
| 1040515700 \| 2 \| 0 \| Caliginis Excelsior | changed: frame | Raffiniert Arquebus: gbf.wiki Template:Weapon_Skills/Excelsior: "Unboostable", one tier (5.5/10/15), no size. Size `big` was left by the retired icon derivation (0248b08f). Data unchanged: canonical Excelsior row is s… |
| 1040518900 \| 1 \| 0 \| Blaze's Crux | changed: frame | Firework Galvanizer: gbf.wiki Template:Weapon_Skills/Crux, section "Unboostable Crux": no size (only Boostable Normal/Taboo are Big). Data unchanged: `Crux\\|ca_supp\\|ex\\|big` is the only EX row and resolves without… |
| 1040606200 \| 0 \| 0 \| Feral Roar | changed: frame | Souval Gauntlet: Unique MC-only skill; no 'Roar' family. Link was inert. |
| 1040613000 \| 2 \| 0 \| Terrae Excelsior | changed: frame | Hard Knuckle: gbf.wiki Template:Weapon_Skills/Excelsior: "Unboostable", one tier (5.5/10/15), no size. Size `big` was left by the retired icon derivation (0248b08f). Data unchanged: canonical Excelsior row is sizeless. |
| 1040700400 \| 1 \| 0 \| Elegant Stratagem | changed: frame | Aetherial Bow: Page (Aetherial Bow s2): 10% MC debuff success. gbf.wiki Template:Weapon_Skills/Stratagem is crit amp; link was inert for data. |
| 1040705600 \| 0 \| 0 \| Forest Blessing | changed: data, frame | Silver Bow: Page (Silver Bow s1): 'Big boost to wind allies' ATK', icon `ws_skill_atk_a_4_3` (EX Might). gbf.wiki Template:Weapon_Skills/Blessing is elem. amplify vs weaker element (seraphic icon); the elem_amplify ro… |
| 1040715000 \| 2 \| 0 \| Arsus Excelsior | changed: frame | Equinius: gbf.wiki Template:Weapon_Skills/Excelsior: "Unboostable", one tier (5.5/10/15), no size. Size `big` was left by the retired icon derivation (0248b08f). Data unchanged: canonical Excelsior row is sizeless. |
| 1040813600 \| 2 \| 0 \| Terrae Excelsior | changed: frame | Heart of a Songbird: gbf.wiki Template:Weapon_Skills/Excelsior: "Unboostable", one tier (5.5/10/15), no size. Size `big` was left by the retired icon derivation (0248b08f). Data unchanged: canonical Excelsior row is s… |
| 1040817200 \| 2 \| 0 \| Blaze's Crux | changed: frame | Shati Hariq: gbf.wiki Template:Weapon_Skills/Crux, section "Unboostable Crux": no size (only Boostable Normal/Taboo are Big). Data unchanged: `Crux\\|ca_supp\\|ex\\|big` is the only EX row and resolves without a size. |
| 1040911900 \| 2 \| 0 \| Caliginis Excelsior | changed: frame | Alabaster Zenith: gbf.wiki Template:Weapon_Skills/Excelsior: "Unboostable", one tier (5.5/10/15), no size. Size `big` was left by the retired icon derivation (0248b08f). Data unchanged: canonical Excelsior row is size… |
| 1040918000 \| 2 \| 0 \| Tranquility's Crux | changed: frame | Moon Shotel: gbf.wiki Template:Weapon_Skills/Crux, section "Unboostable Crux": no size (only Boostable Normal/Taboo are Big). Data unchanged: `Crux\\|ca_supp\\|ex\\|big` is the only EX row and resolves without a size. |

### illustrious (26)

| Version | Change | Why |
|---|---|---|
| 1040115700 \| 0 \| 1 \| Thunder God's Authority II | added | Transcendence tier added to the wiki after the June import; today's database never stored it. The build reads it from the page with gate 220/5/2. |
| 1040115700 \| 1 \| 1 \| Thunder God's Subjugation II | added | Transcendence tier added to the wiki after the June import; today's database never stored it. The build reads it from the page with gate 210/5/1. |
| 1040115700 \| 1 \| 2 \| Thunder God's Subjugation III | added | Transcendence tier added to the wiki after the June import; today's database never stored it. The build reads it from the page with gate 240/5/4. |
| 1040115700 \| 3 \| 1 \| Thunder God's Retribution II | added | Transcendence tier added to the wiki after the June import; today's database never stored it. The build reads it from the page with gate 250/5/5. |
| 1040217300 \| 0 \| 0 \| Purity of Nature | changed: frame | False 'Nature' family link dropped: unique Illustrious MC-only skill (job_weapon icon), no 'Nature' family template; the link was inert (no rows). |
| 1040217300 \| 0 \| 1 \| Purity of Nature II | added | Transcendence tier added to the wiki after the June import; today's database never stored it. The build reads it from the page with gate 210/5/1. |
| 1040217300 \| 0 \| 2 \| Purity of Nature III | added | Transcendence tier added to the wiki after the June import; today's database never stored it. The build reads it from the page with gate 240/5/4. |
| 1040217300 \| 1 \| 1 \| Fine Wind, Clear Heart II | added | Transcendence tier added to the wiki after the June import; today's database never stored it. The build reads it from the page with gate 220/5/2. |
| 1040217300 \| 3 \| 1 \| Crimson Splendor II | added | Transcendence tier added to the wiki after the June import; today's database never stored it. The build reads it from the page with gate 250/5/5. |
| 1040616300 \| 0 \| 1 \| Ogre's Retribution II | added | Transcendence tier added to the wiki after the June import; today's database never stored it. The build reads it from the page with gate 210/5/1. |
| 1040616300 \| 0 \| 2 \| Ogre's Retribution III | added | Transcendence tier added to the wiki after the June import; today's database never stored it. The build reads it from the page with gate 240/5/4. |
| 1040616300 \| 1 \| 1 \| Eternal Animosity II | added | Transcendence tier added to the wiki after the June import; today's database never stored it. The build reads it from the page with gate 220/5/2. |
| 1040616300 \| 3 \| 1 \| Ferocious Dominance II | added | Transcendence tier added to the wiki after the June import; today's database never stored it. The build reads it from the page with gate 250/5/5. |
| 1040711700 \| 0 \| 1 \| Sangre Caliente II | added | Transcendence tier added to the wiki after the June import; today's database never stored it. The build reads it from the page with gate 210/5/1. |
| 1040711700 \| 1 \| 1 \| Robar Tiempo II | added | Transcendence tier added to the wiki after the June import; today's database never stored it. The build reads it from the page with gate 220/5/2. |
| 1040711700 \| 2 \| 1 \| Lluvia de Saetas II | added | Transcendence tier added to the wiki after the June import; today's database never stored it. The build reads it from the page with gate 240/5/4. |
| 1040711700 \| 3 \| 1 \| Dos Colmillos II | added | Transcendence tier on the wiki that today's database never stored. The page gives no s4_u1_lvl; Template:Weapon/Common/Illustrious maps s4_u1 onto s4_4s ('\|s4_4s_name={{{s4_4s_name\|{{{s4_u1_name\|}}}}}}') and fixes … |
| 1040814400 \| 0 \| 1 \| Cepheid Variable II | added | Transcendence tier added to the wiki after the June import; today's database never stored it. The build reads it from the page with gate 210/5/1. |
| 1040814400 \| 1 \| 1 \| Galactic Bulge II | added | Transcendence tier added to the wiki after the June import; today's database never stored it. The build reads it from the page with gate 220/5/2. |
| 1040814400 \| 1 \| 2 \| Galactic Bulge III | added | Transcendence tier added to the wiki after the June import; today's database never stored it. The build reads it from the page with gate 240/5/4. |
| 1040814400 \| 3 \| 1 \| Galactic Halo II | added | Transcendence tier on the wiki that today's database never stored. The page gives no s4_u1_lvl; Template:Weapon/Common/Illustrious maps s4_u1 onto s4_4s ('\|s4_4s_name={{{s4_4s_name\|{{{s4_u1_name\|}}}}}}') and fixes … |
| 1040913400 \| 1 \| 2 \| Blazing Chain III | changed: effects | New cb_amp static 50 row from the stored page text: '\|s2_5s_desc=...10% boost to special C.A. damage cap, and amplify chain damage by 50%.' Today's database predates that text. The ca_dmg_cap 10 row is unchanged. |
| 1040913500 \| 0 \| 1 \| Nue's Omen II | added | Transcendence tier added to the wiki after the June import; today's database never stored it. The build reads it from the page with gate 210/5/1. |
| 1040913500 \| 0 \| 2 \| Nue's Omen III | added | Transcendence tier added to the wiki after the June import; today's database never stored it. The build reads it from the page with gate 240/5/4. |
| 1040913500 \| 1 \| 1 \| Nue's Cry II | added | Transcendence tier added to the wiki after the June import; today's database never stored it. The build reads it from the page with gate 220/5/2. |
| 1040913500 \| 3 \| 1 \| Nue's Calamity II | added | Transcendence tier added to the wiki after the June import; today's database never stored it. The build reads it from the page with gate 250/5/5. |

### revans (6)

| Version | Change | Why |
|---|---|---|
| 1040117600 \| 3 \| 0 \| Zenith Strike: Light | changed: gate | Mk II gate nil/3/0 -> 120/4/0. The Mk II page only transcludes its Mk I ('{{:Concordia'), so its skills are the Mk I's; the template sets '\|s2_lvl=120', and the Mk I already has 120/4/0 through its revans.json gate o… |
| 1040316700 \| 3 \| 0 \| Striking Art: Earth | changed: gate | Mk II gate nil/3/0 -> 120/4/0. The Mk II page only transcludes its Mk I ('{{:Claw of the Dragonslayer'), so its skills are the Mk I's; the template sets '\|s2_lvl=120', and the Mk I already has 120/4/0 through its rev… |
| 1040316900 \| 3 \| 0 \| Zenith Art: Wind | changed: gate | Mk II gate nil/3/0 -> 120/4/0. The Mk II page only transcludes its Mk I ('{{:Spada di Vento'), so its skills are the Mk I's; the template sets '\|s2_lvl=120', and the Mk I already has 120/4/0 through its revans.json g… |
| 1040618000 \| 3 \| 0 \| Zenith Art: Water | changed: gate | Mk II gate nil/3/0 -> 120/4/0. The Mk II page only transcludes its Mk I ('{{:Lagrange'), so its skills are the Mk I's; the template sets '\|s2_lvl=120', and the Mk I already has 120/4/0 through its revans.json gate op… |
| 1040713000 \| 3 \| 0 \| Striking Art: Fire | changed: gate | Mk II gate nil/3/0 -> 120/4/0. The Mk II page only transcludes its Mk I ('{{:Mortality Bow'), so its skills are the Mk I's; the template sets '\|s2_lvl=120', and the Mk I already has 120/4/0 through its revans.json ga… |
| 1040816100 \| 3 \| 0 \| Zenith Strike: Dark | changed: gate | Mk II gate nil/3/0 -> 120/4/0. The Mk II page only transcludes its Mk I ('{{:Forsaken Agastia'), so its skills are the Mk I's; the template sets '\|s2_lvl=120', and the Mk I already has 120/4/0 through its revans.json… |

### malice (5)

| Version | Change | Why |
|---|---|---|
| 1040111000 \| 0 \| 0 \| Coeli Excelsior | changed: frame | Size 'big' dropped: Template:Weapon_Skills/Excelsior is unboostable, one tier, no size; 'big' came from the retired icon derivation (0248b08f). Frame only: the canonical Excelsior row is sizeless, so the data is uncha… |
| 1040112300 \| 1 \| 0 \| Aquae Excelsior | changed: frame | Size 'big' dropped: Template:Weapon_Skills/Excelsior is unboostable, one tier, no size; 'big' came from the retired icon derivation (0248b08f). Frame only: the canonical Excelsior row is sizeless, so the data is uncha… |
| 1040314000 \| 1 \| 0 \| Luminis Excelsior | changed: frame | Size 'big' dropped: Template:Weapon_Skills/Excelsior is unboostable, one tier, no size; 'big' came from the retired icon derivation (0248b08f). Frame only: the canonical Excelsior row is sizeless, so the data is uncha… |
| 1040711000 \| 0 \| 0 \| Snowfall's Crux | changed: frame | Size 'big' dropped: Template:Weapon_Skills/Crux section 'Unboostable Crux' has no size (only boostable Normal/Taboo are Big). Frame only: Crux\|ca_supp\|ex\|big is the only EX row and resolves without a size. |
| 1040711000 \| 1 \| 0 \| Bow Voltage | changed: effects | Colomba's Gameplay Notes now compile a generated 'Bow Voltage' ex_atk_sp per_grid_count 4% row (cap 80, voltage_wrath_grand_epic, same_weapon_type), which wins over the canonical 'Voltage' effect it duplicates (linked… |

### world (5)

| Version | Change | Why |
|---|---|---|
| 1040815000 \| 3 \| 0 \| Sephirath Eparc II | changed: gate | The Sephirath II tier unlocks at level 150; the world.json op (July recovery) set only min_uncap 4 for the same tier, leaving unlock_level nil. The build reads the series template's level. One of the W8 gate 2 '5 Seph… |
| 1040815100 \| 3 \| 0 \| Sephirath Fusame II | changed: gate | The Sephirath II tier unlocks at level 150; the world.json op (July recovery) set only min_uncap 4 for the same tier, leaving unlock_level nil. The build reads the series template's level. One of the W8 gate 2 '5 Seph… |
| 1040815200 \| 3 \| 0 \| Sephirath Brogue II | changed: gate | The Sephirath II tier unlocks at level 150; the world.json op (July recovery) set only min_uncap 4 for the same tier, leaving unlock_level nil. The build reads the series template's level. One of the W8 gate 2 '5 Seph… |
| 1040815300 \| 3 \| 0 \| Sephirath Corant II | changed: gate | The Sephirath II tier unlocks at level 150; the world.json op (July recovery) set only min_uncap 4 for the same tier, leaving unlock_level nil. The build reads the series template's level. One of the W8 gate 2 '5 Seph… |
| 1040815400 \| 3 \| 0 \| Sephirath Haton II | changed: gate | The Sephirath II tier unlocks at level 150; the world.json op (July recovery) set only min_uncap 4 for the same tier, leaving unlock_level nil. The build reads the series template's level. One of the W8 gate 2 '5 Seph… |

### ennead (4)

| Version | Change | Why |
|---|---|---|
| 1040420400 \| 0 \| 0 \| Blaze's Crux | changed: frame | Unboostable Crux has no size (only Boostable Normal/Taboo Crux are Big). Frame-only: Crux\|ca_supp\|ex\|big is the only EX row and resolves without a size. |
| 1040420400 \| 1 \| 0 \| Arsus Excelsior | changed: frame | Excelsior is unboostable with one tier and no size; the stored size 'big' came from the retired icon derivation (0248b08f). Frame-only: the canonical Excelsior row is sizeless, so the resolved data is unchanged. |
| 1040913300 \| 0 \| 0 \| Glimmer's Crux | changed: frame | Unboostable Crux has no size (only Boostable Normal/Taboo Crux are Big). Frame-only: Crux\|ca_supp\|ex\|big is the only EX row and resolves without a size. |
| 1040913300 \| 1 \| 0 \| Luminis Excelsior | changed: frame | Excelsior is unboostable with one tier and no size; the stored size 'big' came from the retired icon derivation (0248b08f). Frame-only: the canonical Excelsior row is sizeless, so the resolved data is unchanged. |

### celestial (3)

| Version | Change | Why |
|---|---|---|
| 1040517100 \| 3 \| 0 \| Gun Voltage II | added | The same version at its new position 3, with the same gate (nil/3/0), frame and generated per_grid_count ex_atk_sp 8 row as the removed position-5 key. |
| 1040517100 \| 3 \| 0 \| Papillon Flamboyant | removed | 'Papillon Flamboyant' is the page's charge attack ('\|ougi_name=Papillon Flamboyant'), left behind by an old import of the expansion's charge-attack table. No rows, no curation. |
| 1040517100 \| 5 \| 0 \| Gun Voltage II | removed | Gun Voltage II moves from position 5 to 3 (see the added key 1040517100\|3\|0\|Gun Voltage II). Template:Weapon/Common/Celestial's s1 is the garbled '{{ #var: weapon_voltage }} Voltage II', so the expansion's skill is… |

### astral (2)

| Version | Change | Why |
|---|---|---|
| 1040416600 \| 3 \| 0 \| Astral Arts | changed: data, frame | False 'Arts' family join (like Architect Battle Arts): Astral Arts is a main-weapon skill DMG cap boost per buff, not Template:Weapon Skills/Arts' flat skill-level curve. Dropping the link removes a wrong skill_dmg_ca… |
| 1040416600 \| 4 \| 0 \| Astral Arts II | changed: data, frame | False 'Arts' family join (like Architect Battle Arts): Astral Arts is a main-weapon skill DMG cap boost per buff, not Template:Weapon Skills/Arts' flat skill-level curve. Dropping the link removes a wrong skill_dmg_ca… |

### epic (2)

| Version | Change | Why |
|---|---|---|
| 1040208100 \| 1 \| 0 \| Terrae Excelsior | changed: frame | Excelsior is unboostable with one tier and no size; the stored size 'big' came from the retired icon derivation (0248b08f). Frame-only: the canonical Excelsior row is sizeless, so the resolved data is unchanged. |
| 1040307100 \| 1 \| 0 \| Caliginis Excelsior | changed: frame | Excelsior is unboostable with one tier and no size; the stored size 'big' came from the retired icon derivation (0248b08f). Frame-only: the canonical Excelsior row is sizeless, so the resolved data is unchanged. |

### event (2)

| Version | Change | Why |
|---|---|---|
| 1030109600 \| 0 \| 0 \| Willed Grounds | added | Beach Flag: Stored wikitext has `s1_name`/`s1_desc`; the weapon had no skills in the DB at all (never persisted). gbf.wiki weapon page, skill 1. The build creates it from the page. |
| 1040027700 \| 1 \| 0 \| Drago Surge | changed: effects, frame | Magic Sword Tenma: Tail-word false join. Page: MC-only boost to C.A. DMG. gbf.wiki Template:Weapon_Skills/Surge is DA/TA rate; its DA/TA rows were phantoms. The dropped rows are the phantom family rows w2-classificati… |

### exo (2)

| Version | Change | Why |
|---|---|---|
| 1040424300 \| 3 \| 0 \| Solaris's Supremacy: Decimation | added | Tier new on the wiki (page set 5star_date=2026-09-07); the database never had the version. The build emits it at position 3 with gate 200/5/0 and the same Supremacy: Decimation massive rows (atk 9/18/23/25.5, dmg_cap … |
| 1040618400 \| 3 \| 0 \| Solaris's Supremacy: Decimation | added | Tier new on the wiki (page set 5star_date=2026-09-07); the database never had the version. The build emits it at position 3 with gate 200/5/0 and the same Supremacy: Decimation massive rows (atk 9/18/23/25.5, dmg_cap … |

### grand (2)

| Version | Change | Why |
|---|---|---|
| 1040207000 \| 0 \| 0 \| Zion's Might II | changed: data, frame | Hatnote page ({{About\|the Grand weapon\|...\|Edem}}) the old parser couldn't read, so the stored sizes predate today's parser. The page's own descriptions give a 'II' Big (big_ii) and Massive; the rows follow the siz… |
| 1040207000 \| 0 \| 1 \| Zion's Might III | changed: data, frame | Hatnote page ({{About\|the Grand weapon\|...\|Edem}}) the old parser couldn't read, so the stored sizes predate today's parser. The page's own descriptions give a 'II' Big (big_ii) and Massive; the rows follow the siz… |

### primal (2)

| Version | Change | Why |
|---|---|---|
| 1040107900 \| 1 \| 1 \| Ventosus's Might II | changed: data, frame | Size medium -> big_ii (and the data follows: canonical Might\|normal\|big_ii 7/16/20/22 instead of medium 3/12/14.5/16). Plume of Suparna is an {{About}}-hatnote page the old parser couldn't read; its stored size pred… |
| 1040606000 \| 0 \| 0 \| Hoarfrost's Tyranny | changed: data, effects, frame | Size small -> big. Wilhelm is an {{About}}-hatnote page the old parser couldn't read. With size big, the family's canonical rows resolve: Tyranny\|atk\|normal_omega\|big 6/15/18 (aura_boostable true) and Tyranny\|hp_c… |

### regalia (2)

| Version | Change | Why |
|---|---|---|
| 1040110300 \| 1 \| 0 \| Terrae Excelsior | changed: frame | Excelsior is unboostable with one tier and no size; the stored size 'big' came from the retired icon derivation (0248b08f). Frame-only: the canonical Excelsior row is sizeless, so the resolved data is unchanged. |
| 1040414100 \| 1 \| 0 \| Aquae Excelsior | changed: frame | Excelsior is unboostable with one tier and no size; the stored size 'big' came from the retired icon derivation (0248b08f). Frame-only: the canonical Excelsior row is sizeless, so the resolved data is unchanged. |

### superlative (2)

| Version | Change | Why |
|---|---|---|
| 1040406900 \| 1 \| 0 \| Saving Grace | changed: frame | False 'Grace' family join: Template:Weapon Skills/Grace is '[{{wsSize}}] boost to [element] allies' max HP and debuff resistance', but Saving Grace is an MC-only cooldown cut. The link was inert (no rows); the 'medium… |
| 1040406900 \| 1 \| 1 \| Saving Grace II | changed: frame | False 'Grace' family join: Template:Weapon Skills/Grace is '[{{wsSize}}] boost to [element] allies' max HP and debuff resistance', but Saving Grace is an MC-only cooldown cut. The link was inert (no rows); the 'medium… |

### vintage (2)

| Version | Change | Why |
|---|---|---|
| 1040400300 \| 0 \| 0 \| Grace of Healing | changed: frame | False 'Healing' family join: Template:Weapon Skills/Healing is heal cap ('[{{wsSize}}] boost to [element] allies' healing cap'), but Grace of Healing is a boost to healing (icon ws_skill_heal, not heal_limit). Frame-o… |
| 1040400300 \| 0 \| 1 \| Grace of Healing II | changed: frame | False 'Healing' family join: Template:Weapon Skills/Healing is heal cap ('[{{wsSize}}] boost to [element] allies' healing cap'), but Grace of Healing is a boost to healing (icon ws_skill_heal, not heal_limit). Frame-o… |

### beast (1)

| Version | Change | Why |
|---|---|---|
| 1040207700 \| 1 \| 0 \| Scales of Wrath | changed: effects, frame | Qinglong Spear Pontus: Tail-word false join. Page: MC-only 20% Bonus DMG below 50% HP. gbf.wiki Template:Weapon_Skills/Wrath is per-grid EX Might Sp./HP/DA/TA; those rows were phantoms. The dropped rows are the phanto… |

### collab (1)

| Version | Change | Why |
|---|---|---|
| 1040425100 \| 2 \| 0 \| Caliginis Excelsior | changed: frame | Bandit's Secret: gbf.wiki Template:Weapon_Skills/Excelsior: "Unboostable", one tier (5.5/10/15), no size. Size `big` was left by the retired icon derivation (0248b08f). Data unchanged: canonical Excelsior row is sizel… |

### xeno (1)

| Version | Change | Why |
|---|---|---|
| 1040213300 \| 1 \| 0 \| Undersky's Whispers | changed: frame | Hatnote page ({{About\|the Xeno weapon\|...}}) the old parser couldn't read; the build reads the description's size word 'Big'. Frame-only: the existing data row is already enmity/ex/big. One of the W8 gate 2 '8 hatno… |
