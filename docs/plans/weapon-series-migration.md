# Plan: Convert WeaponSeries from Enum to Database Table

## Summary
Convert the hardcoded `SERIES_SLUGS` hash in `Weapon` model to a `weapon_series` database table with full CRUD API support, enabling dynamic management of weapon series without code deploys.

## New Table: `weapon_series`

| Column | Type | Notes |
|--------|------|-------|
| id | uuid | Primary key |
| name_en | string | English name |
| name_jp | string | Japanese name |
| slug | string | Unique identifier (e.g., 'dark-opus') |
| order | integer | Sort order for display |
| extra | boolean | Allowed in extra grid positions (9, 10, 11) |
| element_changeable | boolean | Weapon element can be changed |
| has_weapon_keys | boolean | Series supports weapon keys |
| has_awakening | boolean | Series supports awakenings |
| has_ax_skills | boolean | Series supports AX skills |

## Implementation Steps

### Phase 1: Database Setup

1. **Create `weapon_series` table migration**
   - `db/migrate/TIMESTAMP_create_weapon_series.rb`
   - UUID primary key, unique index on slug, index on order

2. **Add `weapon_series_id` to weapons table**
   - `db/migrate/TIMESTAMP_add_weapon_series_id_to_weapons.rb`
   - Foreign key reference, nullable initially

3. **Create `weapon_key_series` join table**
   - `db/migrate/TIMESTAMP_create_weapon_key_series.rb`
   - Many-to-many between weapon_keys and weapon_series
   - Replaces the integer array `weapon_keys.series` column

### Phase 2: Models

4. **Create `WeaponSeries` model**
   - File: `app/models/weapon_series.rb`
   - Associations: `has_many :weapons`, `has_many :weapon_key_series`, `has_many :weapon_keys, through: :weapon_key_series`
   - Validations: presence for name_en, name_jp, slug; uniqueness for slug
   - Scopes: `ordered`, `extra_allowed`, `element_changeable`, etc.

5. **Create `WeaponKeySeries` join model**
   - File: `app/models/weapon_key_series.rb`
   - Belongs to weapon_key and weapon_series

6. **Update `Weapon` model**
   - File: `app/models/weapon.rb`
   - Add `belongs_to :weapon_series, optional: true`
   - Update `opus_or_draconic?` to use `weapon_series.slug`
   - Update `draconic_or_providence?` to use `weapon_series.slug`
   - Update `element_changeable?` to use `weapon_series.element_changeable`
   - Update `compatible_with_key?` to use new relationship
   - Keep `SERIES_SLUGS` temporarily for backwards compatibility

7. **Update `WeaponKey` model**
   - File: `app/models/weapon_key.rb`
   - Add `has_many :weapon_key_series` and `has_many :weapon_series, through: :weapon_key_series`

8. **Update `GridWeapon` model**
   - File: `app/models/grid_weapon.rb`
   - Replace `ALLOWED_EXTRA_SERIES` constant with `weapon.weapon_series&.extra` check

### Phase 3: Data Migration

9. **Populate weapon_series table**
   - `db/data/TIMESTAMP_populate_weapon_series.rb`
   - Create 45 series records from existing `SERIES_SLUGS`
   - Set boolean flags appropriately for each series

10. **Migrate weapons to use weapon_series_id**
    - `db/data/TIMESTAMP_migrate_weapons_to_weapon_series.rb`
    - Map legacy integer `series` to new `weapon_series_id`

11. **Migrate weapon_key series to join table**
    - `db/data/TIMESTAMP_migrate_weapon_key_series.rb`
    - Convert integer arrays to `weapon_key_series` records

### Phase 4: API

12. **Create `WeaponSeriesBlueprint`**
    - File: `app/blueprints/api/v1/weapon_series_blueprint.rb`
    - Fields: name (en/ja), slug, order
    - Full view: include boolean flags

13. **Create `WeaponSeriesController`**
    - File: `app/controllers/api/v1/weapon_series_controller.rb`
    - Actions: index, show, create (admin), update (admin), destroy (admin)
    - Lookup by slug or id

14. **Add routes**
    - File: `config/routes.rb`
    - `resources :weapon_series, only: [:index, :show, :create, :update, :destroy]`

15. **Update `WeaponBlueprint`**
    - File: `app/blueprints/api/v1/weapon_blueprint.rb`
    - Change `series` field to return object: `{ id, slug, name: { en, ja } }`
    - Keep legacy `series` integer for backwards compatibility during transition

16. **Update `GridWeaponBlueprint`**
    - File: `app/blueprints/api/v1/grid_weapon_blueprint.rb`
    - Update weapon_keys conditional to use `weapon.weapon_series&.has_weapon_keys`

### Phase 5: Service Updates

17. **Update `WeaponProcessor`**
    - File: `app/services/processors/weapon_processor.rb`
    - Map incoming `series_id` integers to `weapon_series_id` UUIDs
    - Update `element_changeable?` calls

18. **Update `CollectionWeapon` model**
    - File: `app/models/collection_weapon.rb`
    - Update `by_series` scope to use `weapon_series_id`
    - Update validations to use new associations

### Phase 6: Testing

19. **Create `WeaponSeries` factory**
    - File: `spec/factories/weapon_series.rb`
    - Traits for common series types (opus, draconic, etc.)

20. **Update existing specs**
    - Update weapon factory to use weapon_series association
    - Add tests for new controller endpoints
    - Add tests for model methods

## Files to Modify

| File | Changes |
|------|---------|
| `app/models/weapon.rb` | Add association, update methods |
| `app/models/weapon_key.rb` | Add associations |
| `app/models/grid_weapon.rb` | Replace ALLOWED_EXTRA_SERIES |
| `app/models/collection_weapon.rb` | Update scope and validations |
| `app/blueprints/api/v1/weapon_blueprint.rb` | Update series field |
| `app/blueprints/api/v1/grid_weapon_blueprint.rb` | Update conditional |
| `app/services/processors/weapon_processor.rb` | Update series lookups |
| `config/routes.rb` | Add weapon_series routes |

## New Files to Create

| File | Purpose |
|------|---------|
| `app/models/weapon_series.rb` | WeaponSeries model |
| `app/models/weapon_key_series.rb` | Join table model |
| `app/controllers/api/v1/weapon_series_controller.rb` | CRUD controller |
| `app/blueprints/api/v1/weapon_series_blueprint.rb` | API serializer |
| `db/migrate/*_create_weapon_series.rb` | Table migration |
| `db/migrate/*_add_weapon_series_id_to_weapons.rb` | FK migration |
| `db/migrate/*_create_weapon_key_series.rb` | Join table migration |
| `db/data/*_populate_weapon_series.rb` | Seed data |
| `db/data/*_migrate_weapons_to_weapon_series.rb` | Data migration |
| `db/data/*_migrate_weapon_key_series.rb` | WeaponKey data migration |
| `spec/factories/weapon_series.rb` | Test factory |

## Boolean Flags by Series

Key series with special flags:
- **element_changeable**: revenant, ultima, superlative, class-champion
- **extra**: xeno, cosmos, superlative, eternal-splendor, ancestral, militis, menace
- **has_weapon_keys**: grand, dark-opus, superlative, vyrmament, menace
- **has_awakening**: (to be determined based on current weapon data)
- **has_ax_skills**: (to be determined based on current weapon data)

## API Response Format

```json
// GET /weapon_series
[
  {
    "id": "uuid",
    "name": { "en": "Dark Opus", "ja": "オプス" },
    "slug": "dark-opus",
    "order": 3
  }
]

// GET /weapons/:id (updated series field)
{
  "id": "uuid",
  "series": {
    "id": "series-uuid",
    "slug": "dark-opus",
    "name": { "en": "Dark Opus", "ja": "オプス" }
  }
}
```

## Backwards Compatibility

- Keep legacy `series` integer column on weapons until frontend is updated
- API can return both formats during transition period
- `SERIES_SLUGS` constant can be removed after migration is complete
