# Collection Tracking Feature Plan

## Overview

The Collection Tracking feature enables users to maintain a comprehensive inventory of their Granblue Fantasy game items. This system is distinct from the existing grid/party system and focuses on cataloging what items users own rather than how they use them in team compositions.

## Business Requirements

### User Stories

1. **As a user**, I want to record which characters I own so I can keep track of my collection progress.
2. **As a user**, I want to save character customizations (rings, awakenings, transcendence) so I can reference them when building teams.
3. **As a user**, I want to track multiple copies of the same weapon/summon with different properties so I can manage my duplicates.
4. **As a user**, I want to record my job accessories collection so I know which ones I still need to obtain.
5. **As a user**, I want to import/export my collection data so I can backup or share my inventory.
6. **As a user**, I want to see statistics about my collection so I can track my progress.

### Core Concepts

#### Collection vs Grid Items
- **Grid Items** (GridCharacter, GridWeapon, GridSummon): Represent items configured within a specific party/team
- **Collection Items**: Represent the user's overall inventory, independent of any party configuration

#### Item Uniqueness Rules
- **Characters**: One instance per character (by granblue_id) per user
- **Weapons**: Multiple instances of the same weapon allowed, each with unique properties
- **Summons**: Multiple instances of the same summon allowed, each with unique properties
- **Job Accessories**: One instance per accessory (by granblue_id) per user

## Technical Design

### Database Schema

#### users table additions
```sql
- collection_privacy: integer (default: 0, not null)
  # 0 = public (viewable by everyone)
  # 1 = crew_only (viewable by crew members only)
  # 2 = private (viewable by owner only)

Index:
- index on collection_privacy
```

#### collection_characters
```sql
- id: uuid (primary key)
- user_id: uuid (foreign key to users)
- character_id: uuid (foreign key to characters)
- uncap_level: integer (0-5)
- transcendence_step: integer (0-10)
- perpetuity: boolean
- awakening_id: uuid (foreign key to awakenings, optional)
- awakening_level: integer (1-10)
- ring1: jsonb {modifier: integer, strength: float}
- ring2: jsonb {modifier: integer, strength: float}
- ring3: jsonb {modifier: integer, strength: float}
- ring4: jsonb {modifier: integer, strength: float}
- earring: jsonb {modifier: integer, strength: float}
- created_at: timestamp
- updated_at: timestamp

Indexes:
- unique index on [user_id, character_id]
- index on user_id
- index on character_id
```

#### collection_weapons
```sql
- id: uuid (primary key)
- user_id: uuid (foreign key to users)
- weapon_id: uuid (foreign key to weapons)
- uncap_level: integer (0-5)
- transcendence_step: integer (0-10)
- weapon_key1_id: uuid (foreign key to weapon_keys, optional)
- weapon_key2_id: uuid (foreign key to weapon_keys, optional)
- weapon_key3_id: uuid (foreign key to weapon_keys, optional)
- weapon_key4_id: uuid (foreign key to weapon_keys, optional)
- awakening_id: uuid (foreign key to awakenings, optional)
- awakening_level: integer (1-10)
- ax_modifier1: integer
- ax_strength1: float
- ax_modifier2: integer
- ax_strength2: float
- element: integer (for element-changeable weapons)
- created_at: timestamp
- updated_at: timestamp

Indexes:
- index on user_id
- index on weapon_id
- index on [user_id, weapon_id]
```

#### collection_summons
```sql
- id: uuid (primary key)
- user_id: uuid (foreign key to users)
- summon_id: uuid (foreign key to summons)
- uncap_level: integer (0-5)
- transcendence_step: integer (0-10)
- created_at: timestamp
- updated_at: timestamp

Indexes:
- index on user_id
- index on summon_id
- index on [user_id, summon_id]
```

#### collection_job_accessories
```sql
- id: uuid (primary key)
- user_id: uuid (foreign key to users)
- job_accessory_id: uuid (foreign key to job_accessories)
- created_at: timestamp
- updated_at: timestamp

Indexes:
- unique index on [user_id, job_accessory_id]
- index on user_id
- index on job_accessory_id
```

### Model Relationships

```ruby
# User model additions
has_many :collection_characters, dependent: :destroy
has_many :collection_weapons, dependent: :destroy
has_many :collection_summons, dependent: :destroy
has_many :collection_job_accessories, dependent: :destroy

# CollectionCharacter
belongs_to :user
belongs_to :character
belongs_to :awakening, optional: true
validates :character_id, uniqueness: { scope: :user_id }

# CollectionWeapon
belongs_to :user
belongs_to :weapon
belongs_to :awakening, optional: true
belongs_to :weapon_key1, class_name: 'WeaponKey', optional: true
belongs_to :weapon_key2, class_name: 'WeaponKey', optional: true
belongs_to :weapon_key3, class_name: 'WeaponKey', optional: true
belongs_to :weapon_key4, class_name: 'WeaponKey', optional: true

# CollectionSummon
belongs_to :user
belongs_to :summon

# CollectionJobAccessory
belongs_to :user
belongs_to :job_accessory
validates :job_accessory_id, uniqueness: { scope: :user_id }
```

### API Design

#### Endpoints

##### Collection Characters
```
GET    /api/v1/collection/characters
  Query params: page, limit
  Response: Paginated list of user's characters

GET    /api/v1/collection/characters/:id
  Response: Single collection character details

POST   /api/v1/collection/characters
  Body: character_id, uncap_level, transcendence_step, rings, etc.
  Response: Created collection character

PUT    /api/v1/collection/characters/:id
  Body: Updated fields
  Response: Updated collection character

DELETE /api/v1/collection/characters/:id
  Response: Success/error status
```

##### Collection Weapons
```
GET    /api/v1/collection/weapons
  Query params: page, limit, weapon_id (filter)
  Response: Paginated list of user's weapons

GET    /api/v1/collection/weapons/:id
  Response: Single collection weapon details

POST   /api/v1/collection/weapons
  Body: weapon_id, uncap_level, keys, ax_modifiers, etc.
  Response: Created collection weapon

PUT    /api/v1/collection/weapons/:id
  Body: Updated fields
  Response: Updated collection weapon

DELETE /api/v1/collection/weapons/:id
  Response: Success/error status
```

##### Collection Summons
```
GET    /api/v1/collection/summons
  Query params: page, limit, summon_id (filter)
  Response: Paginated list of user's summons

GET    /api/v1/collection/summons/:id
  Response: Single collection summon details

POST   /api/v1/collection/summons
  Body: summon_id, uncap_level, transcendence_step
  Response: Created collection summon

PUT    /api/v1/collection/summons/:id
  Body: Updated fields
  Response: Updated collection summon

DELETE /api/v1/collection/summons/:id
  Response: Success/error status
```

##### Collection Job Accessories
```
GET    /api/v1/collection/job_accessories
  Query params: page, limit, job_id (filter)
  Response: Paginated list of user's job accessories

POST   /api/v1/collection/job_accessories
  Body: job_accessory_id
  Response: Created collection job accessory

DELETE /api/v1/collection/job_accessories/:id
  Response: Success/error status
```

##### Collection Management
```
GET    /api/v1/collection/statistics
  Response: {
    total_characters: 150,
    total_weapons: 500,
    total_summons: 200,
    total_job_accessories: 25,
    breakdown_by_element: {...},
    breakdown_by_rarity: {...}
  }

POST   /api/v1/collection/import
  Body: JSON with collection data
  Response: Import results

GET    /api/v1/collection/export
  Response: Complete collection data as JSON
```

### Error Handling

#### Custom Error Classes

```ruby
# app/errors/collection_errors.rb
module CollectionErrors
  class CollectionItemNotFound < StandardError; end
  class DuplicateCharacter < StandardError; end
  class DuplicateJobAccessory < StandardError; end
  class InvalidWeaponKey < StandardError; end
  class InvalidAwakening < StandardError; end
  class InvalidUncapLevel < StandardError; end
  class InvalidTranscendenceStep < StandardError; end
  class CollectionLimitExceeded < StandardError; end
end
```

#### Error Responses

```json
{
  "error": {
    "type": "DuplicateCharacter",
    "message": "Character already exists in collection",
    "details": {
      "character_id": "3040001000",
      "existing_id": "uuid-here"
    }
  }
}
```

### Security Considerations

1. **Authorization**: Collection management endpoints require authentication
2. **Ownership**: Users can only modify their own collection
3. **Privacy Controls**: Three-tier privacy system:
   - **Public**: Viewable by everyone
   - **Crew Only**: Viewable by crew members (future feature)
   - **Private**: Viewable only by the owner
4. **Access Control**: Enforced based on privacy level and viewer relationship
5. **Rate Limiting**: Import/export endpoints have stricter rate limits
6. **Validation**: Strict validation of all input data against game rules

### Performance Considerations

1. **Eager Loading**: Use includes() to avoid N+1 queries
2. **Pagination**: All list endpoints must be paginated
3. **Caching**: Cache statistics and export data (15-minute TTL)
4. **Batch Operations**: Support bulk create/update for imports
5. **Database Indexes**: Proper indexes on foreign keys and common query patterns

## Implementation Phases

### Phase 1: Core Models and Database (Week 1)
- Create migrations for all collection tables
- Implement collection models with validations
- Add model associations and scopes
- Write model specs

### Phase 2: API Controllers and Blueprints (Week 2)
- Implement CRUD controllers for each collection type
- Create blueprint serializers
- Add authentication and authorization
- Write controller specs

### Phase 3: Import/Export and Statistics (Week 3)
- Implement bulk import functionality
- Add export endpoints
- Create statistics aggregation
- Add background job support for large imports

### Phase 4: Frontend Integration (Week 4)
- Update frontend models and types
- Create collection management UI
- Add import/export interface
- Implement collection statistics dashboard

## Success Metrics

1. **Performance**: All endpoints respond within 200ms for standard operations
2. **Reliability**: 99.9% uptime for collection services
3. **User Adoption**: 50% of active users use collection tracking within 3 months
4. **Data Integrity**: Zero data loss incidents
5. **User Satisfaction**: 4+ star rating for the feature

## Future Enhancements

1. **Collection Sharing**: Allow users to share their collection publicly
2. **Collection Goals**: Set targets for collection completion
3. **Collection Comparison**: Compare collections between users
4. **Automated Sync**: Sync with game data via API (if available)
5. **Collection Value**: Calculate total collection value/rarity score
6. **Mobile App**: Native mobile app for collection management
7. **Collection History**: Track changes to collection over time