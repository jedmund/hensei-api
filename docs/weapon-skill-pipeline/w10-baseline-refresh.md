# W10 baseline refresh (batch 1)

What W10's first batch changes in the resolved weapon-skill data. Measured on `catalogue-20261015-w8`, which is prod after the W8 switch: the W8 baseline (#572), compared with a full `build_weapon_skills all=true mode=write` plus the curation sync on this branch. **95 versions change; none is added or removed.** The user approved every value change in this list before merge.

| Change | Versions | Source |
|---|---|---|
| **Blow: Bonus Element DMG 20%** (was an empty canonical row) | 15 | #579. 13 of the 15 Blow pages state 20%; none contradicts it. The "third hit of triple attacks" condition isn't modelled. |
| **Ascendancy: the misread C.A. DMG Cap +10 is removed** (Sp. C.A. Cap 10 stays) | 7 | #578, the `sp_ca_cap` clause. Glimmer's, Blaze's, Ridge's, Purgatory's and Snowfall's Ascendancy, on Fediel Float, Schrodinger and Schrodinger Mk II. |
| **Blazing Chain II/III: the 10 moves from C.A. DMG Cap to Sp. C.A. Cap** | 2 | #578. Page text: "special C.A. damage cap". |
| **Astral Arts / Astral Arts II: per-buff skill DMG cap** (10% per buff, max 50%) | 2 | #582. Adds nothing at the default panel state, which has no buffs. |
| **Hoarfrost's Tyranny (Metal Hand): size small → big**, now on the Tyranny family rows (same numbers; summon auras now amplify its ATK) | 1 | #580. The page says "Big boost"; the size was read from a `text-small` HTML wrapper. |
| **Forest Blessing: Might EX Big curve** (about −3.6 EX ATK at SL15) | 1 | #581. Page text and skill icon (the Might template's EX Big icon). |
| **Self-taught Mastery (Fugudoku): size cleared** | 1 | #580. The size came from an editor comment. The skill has no rows, so values don't change. |
| **Voltage II skills now use the "Voltage II" family** (value stays 8%) | 24 | Template:Weapon Skills/Voltage: Voltage II is 8% per weapon. New Voltage II weapons now get 8% without curation. |
| **Targets only: `element_allies` → `all_allies`** on Voltage and Celestial specialty rows | 41 (+24 above) | The Voltage template and the Celestial pages: "Affects allies of any element". The calculator doesn't read `applies_to` yet. |

**Checks** on that database after the write:
- `granblue:skill_parity` reports no differences against this baseline;
- a second `build_weapon_skills` finds 0 stale weapons;
- the curation drift check is clean;
- the full suite passes (3,971 examples, 0 failures), goldens included.
