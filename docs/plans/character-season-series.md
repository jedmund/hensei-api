# Character Season & Series Implementation Plan

## Overview

Add `season`, `series`, and `gacha_available` columns to the characters table to properly categorize character variants. This replaces the current approach of disambiguating in name fields (e.g., "Vira (SSR)").

**Goals:**
- Clean character names without disambiguation suffixes
- Enable filtering by season/series in the UI
- Support gacha bot queries for pool availability
- Centralize gacha metadata in hensei-api (shared database with siero-bot)

---

## Data Model

### Season (integer, nullable)
Represents the gacha time period when a character can be pulled.

| Value | Name      | Notes |
|-------|-----------|-------|
| 1     | Standard  | Available year-round (in their respective pool) (1-index to work better with Javascript) |
| 2     | Valentine | February |
| 3     | Formal    | June |
| 4     | Summer    | July-August (both Summer and Yukata series) |
| 5     | Halloween | October |
| 6     | Holiday   | December |

### Series (integer array)
Represents the character's identity/pool membership. A character can belong to multiple series (e.g., Summer Zodiac = [summer, zodiac]).

| Value | Name      | Notes |
|-------|-----------|-------|
| 1     | Standard  | Regular gacha pool (1-index to work better with Javascript) |
| 2     | Grand     | Flash Gala and Legend Gacha exclusive |
| 3     | Zodiac    | Legend Fest exclusive, yearly rotation |
| 4     | Promo     | Not in gacha - ticket/code redemption |
| 5     | Collab    | Collaboration events |
| 6     | Eternal   | Free recruitment (Eternals) |
| 7     | Evoker    | Free recruitment (Evokers) |
| 8     | Saint     | Free recruitment (similar to Eternals), may have gacha alts |
| 9     | Fantasy   | Can combine with other series (e.g., Fantasy + Grand) |
| 10    | Summer    | Summer seasonal series |
| 11    | Yukata    | Yukata seasonal series (same gacha window as Summer) |
| 12    | Valentine | Valentine seasonal series |
| 13    | Halloween | Halloween seasonal series |
| 14    | Formal    | Formal seasonal series |
| 15    | Event     | Event reward characters |

### Gacha Available (boolean)
Quick filter for characters that can be pulled in gacha vs those that are recruited.
- `true` - Can be pulled from gacha (Standard, Grand, Zodiac, seasonal series, etc.)
- `false` - Must be recruited (Eternals, Evokers, Saints, Event, Collab)

### Promotion (integer array on weapons/summons)
Move promotion data from the `gacha` table to weapons and summons directly.

| Value | Name       | Notes |
|-------|------------|-------|
| 1     | Premium    | Available in regular Premium draws |
| 2     | Classic    | Available in Classic draws |
| 3     | Classic II | Available in Classic II draws |
| 4     | Flash      | Available in Flash Gala (6% SSR rate) |
| 5     | Legend     | Available in Legend Fest (6% SSR rate) |
| 6     | Valentine  | Valentine seasonal gacha |
| 7     | Summer     | Summer seasonal gacha |
| 8     | Halloween  | Halloween seasonal gacha |
| 9     | Holiday    | Holiday seasonal gacha |
| 10    | Collab     | Collaboration gacha |
| 11    | Formal     | Formal seasonal gacha |

**Decision:** Add `promotions` as integer array on weapons and summons tables, then deprecate the `gacha` table. This eliminates the polymorphic join and simplifies queries.

---

## Implementation Tasks

### Phase 1: Schema Migration

- [x] **Task 1.1:** Create migration to add `season`, `series`, and `gacha_available` columns: `6e62053`

- [x] **Task 1.2:** Add enum constants to `GranblueEnums`: `24d8d20`, `208d1f4`

### Phase 2: Model Updates

- [x] **Task 2.1:** Update `Character` model: `afa1c51`

- [x] **Task 2.2:** Update `CharacterBlueprint`: `a3c33ce`, `cb01658`

### Phase 3: Controller & API Updates

- [x] **Task 3.1:** Update `CharactersController`: `db048dc`

- [x] **Task 3.2:** Update search functionality: `9c5c859`
  - Added `season`, `series`, `gacha_available` filters to characters search
  - Added `promotions` filter to weapons search
  - Added `promotions` filter to summons search
  - Array filters use PostgreSQL `&&` (overlap) operator

### Phase 4: Importer/Parser Updates

- [x] **Task 4.1:** Update `CharacterImporter`: `e0a82bc`
  - Added `season`, `series`, `gacha_available` to `build_attributes`

- [x] **Task 4.2:** Update `CharacterParser`: `e0a82bc`
  - Added `series_from_hash`, `season_from_hash`, `gacha_available_from_hash` methods
  - Extracts data from wiki `|series=` and `|obtain=` fields

- [x] **Task 4.3:** Update `WeaponImporter` and `SummonImporter`: `7aa0521`
  - Added `promotions` to `build_attributes`

- [x] **Task 4.4:** Update `WeaponParser` and `SummonParser`: `c1a5d62`
  - Added `promotions_from_obtain` method
  - Added wiki promotions mapping to `Wiki` class

### Phase 5: Data Migration

- [x] **Task 5.1:** Create rake task to export characters to CSV: `284ee44`

- [ ] **Task 5.2:** User curates CSV with season/series assignments (manual step)

- [x] **Task 5.3:** Create rake task to import curated CSV: `284ee44`

- [ ] **Task 5.4:** Clean up character names (deferred until data populated)

### Phase 6: Frontend Updates (hensei-svelte)

- [x] **Task 6.1:** Update TypeScript types: `67b87c7d`

- [x] **Task 6.2:** Update search adapter: `f26d3e38`

- [x] **Task 6.3:** Add filter UI components (CheckboxGroup): `96f040a9`

- [x] **Task 6.4:** Update character display: `cf694bb1`

- [x] **Task 6.5:** Update weapon display: `8c45c219`

- [x] **Task 6.6:** Update summon display: `23ae7f70`

- [x] **Task 6.7:** Update batch import pages: `1933f3d8`

- [x] **Task 6.8:** Add recruited_by to character metadata: `cf694bb1`

### Phase 7: Weapons/Summons Promotion Migration

- [x] **Task 7.1:** Add `promotions` column to weapons table: `6f64610`

- [x] **Task 7.2:** Add `promotions` column to summons table: `6f64610`

- [x] **Task 7.3:** Add PROMOTIONS enum to `GranblueEnums`: `6f64610`, `208d1f4`

- [x] **Task 7.4:** Create data migration rake task: `49e52ff`

- [x] **Task 7.5:** Update Weapon and Summon models: `e81c559`

- [x] **Task 7.6:** Update WeaponBlueprint and SummonBlueprint: `0dba56c`

- [x] **Task 7.7:** Update controllers to permit `promotions`: `05dd899`

- [ ] **Task 7.8:** Deprecate `gacha` table (after siero-bot deployed and tested)

### Phase 8: Siero-bot Integration

- [x] **Task 8.1:** Update siero-bot to use new columns (branch: `feature/use-promotions-column`)
  - `210b5dc` - Added `PromotionId` enum mapping to hensei-api values
  - `b0e0972` - Added `promotions: number[]` to table interfaces
  - `897d86b` - Rewrote `cache.ts` to query weapons/summons directly
  - `1b7ac14` - Rewrote `api.ts` to remove gacha table dependency
  - `d745b0f` - Changed rateups to use `granblue_id` for stability

---

## Remaining Work (Pre-Deployment Testing Required)

These tasks require testing and/or manual intervention before completion:

### 1. Data Population (Manual)

**Task 5.2: Curate character season/series data**

Options for populating character data:
- **Option A:** Export CSV, manually curate, re-import
  ```bash
  rake characters:export_csv           # Creates lib/seeds/characters_export.csv
  # Edit CSV to add season/series/gacha_available values
  rake characters:import_csv           # Imports curated data
  ```
- **Option B:** Use wiki parser to auto-populate (may need manual review)
  ```bash
  rails runner "Granblue::Parsers::CharacterParser.fetch_all(save: true, overwrite: true)"
  ```

### 2. Siero-bot Deployment

**Deploy and test siero-bot changes before deprecating gacha table:**

1. Merge `feature/use-promotions-column` branch
2. Deploy to production
3. Test gacha simulation commands work correctly
4. Test rateup functionality works correctly
5. Monitor for errors

### 3. Database Cleanup (Destructive)

**Task 7.8: Deprecate `gacha` table**

Only after siero-bot is deployed and verified working:

1. Create migration to drop `gacha` table
2. Remove any remaining references to `Gacha` model
3. Clean up unused code

### 4. Character Name Cleanup (Optional)

**Task 5.4: Remove disambiguation from character names**

After season/series data is populated and frontend displays badges:

1. Remove suffixes like "(SSR)", "(Summer)", "(Grand)" from `name_en`
2. Update any search indexes if needed
3. Verify frontend displays correctly with badges instead of name suffixes

---

## File Changes Summary

### hensei-api

| File | Change |
|------|--------|
| `db/migrate/*_add_season_series_to_characters.rb` | Add season, series, gacha_available columns |
| `db/migrate/*_add_promotions_to_weapons.rb` | Add promotions array column |
| `db/migrate/*_add_promotions_to_summons.rb` | Add promotions array column |
| `lib/tasks/characters.rake` | Export/import rake tasks for data migration |
| `lib/tasks/gacha.rake` | Migration tasks for promotions data |
| `app/models/concerns/granblue_enums.rb` | Add CHARACTER_SEASONS, CHARACTER_SERIES, PROMOTIONS |
| `app/models/character.rb` | Add validations, scopes, helpers |
| `app/models/weapon.rb` | Add promotions validations, scopes, helpers |
| `app/models/summon.rb` | Add promotions validations, scopes, helpers |
| `app/blueprints/api/v1/character_blueprint.rb` | Serialize new fields, recruited_by |
| `app/blueprints/api/v1/weapon_blueprint.rb` | Serialize promotions |
| `app/blueprints/api/v1/summon_blueprint.rb` | Serialize promotions |
| `app/controllers/api/v1/characters_controller.rb` | Permit new params, filtering |
| `app/controllers/api/v1/weapons_controller.rb` | Permit promotions |
| `app/controllers/api/v1/summons_controller.rb` | Permit promotions |
| `app/controllers/api/v1/search_controller.rb` | Add season/series/promotions filters |
| `lib/granblue/importers/character_importer.rb` | Parse new CSV columns |
| `lib/granblue/importers/weapon_importer.rb` | Parse promotions column |
| `lib/granblue/importers/summon_importer.rb` | Parse promotions column |
| `lib/granblue/parsers/character_parser.rb` | Extract season/series from wiki |
| `lib/granblue/parsers/weapon_parser.rb` | Extract promotions from wiki |
| `lib/granblue/parsers/summon_parser.rb` | Extract promotions from wiki |
| `lib/granblue/parsers/wiki.rb` | Add promotions mapping |

### hensei-svelte

| File | Change |
|------|--------|
| `src/lib/types/Character.d.ts` | Add season/series/gachaAvailable fields |
| `src/lib/types/Weapon.d.ts` | Add promotions fields |
| `src/lib/types/Summon.d.ts` | Add promotions fields |
| `src/lib/types/enums.ts` | Add CharacterSeason, CharacterSeries, Promotion enums |
| `src/lib/api/adapters/entity.adapter.ts` | Add new fields to interfaces |
| `src/lib/api/adapters/search.adapter.ts` | Add filter params |
| `src/lib/api/adapters/types.ts` | Add SearchFilters types |
| `src/lib/components/ui/checkbox/CheckboxGroup.svelte` | New multiselect component |
| `src/lib/components/ui/DetailItem.svelte` | Add multiselect type support |
| `src/lib/features/database/characters/schema.ts` | Add to edit schema |
| `src/lib/features/database/characters/sections/CharacterTaxonomySection.svelte` | Add season/series/gacha UI |
| `src/lib/features/database/characters/sections/CharacterMetadataSection.svelte` | Add recruited_by display |
| `src/lib/features/database/weapons/schema.ts` | Add promotions to schema |
| `src/lib/features/database/weapons/sections/WeaponTaxonomySection.svelte` | Add promotions UI |
| `src/lib/features/database/summons/schema.ts` | Add promotions to schema |
| `src/lib/features/database/summons/sections/SummonTaxonomySection.svelte` | Add promotions UI |
| `src/routes/(app)/database/*/import/+page.svelte` | Add new fields to batch import |

### siero-bot (branch: feature/use-promotions-column)

| File | Change |
|------|--------|
| `src/services/cache.ts` | Query promotions from weapons/summons instead of gacha table |
| `src/services/api.ts` | Remove gacha table dependency, use granblue_id for rateups |
| `src/utils/enums.ts` | Add PromotionId enum, mapping helpers |
| `src/services/tables.ts` | Add promotions to WeaponTable and SummonTable |

---

## Notes

- The `character_id` array field will remain unchanged (no rename)
- `gacha_available` boolean added for quick filtering of pullable vs recruited characters
- All enums are 1-indexed to work better with JavaScript/TypeScript
- `gacha` table will be deprecated after siero-bot migration is complete
- Season values represent gacha availability windows (when you can pull)
- Series values represent character identity (what pool/category they belong to)
- Wiki uses "gala" for Flash Gala weapons (mapped to Flash promotion ID 4)
