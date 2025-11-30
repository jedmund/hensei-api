# Artifacts Feature Plan

## Overview

Artifacts are character equipment items in Granblue Fantasy that provide stat bonuses through a skill system. This document outlines the implementation plan for tracking artifacts in user collections and parties, following the same pattern as the existing weapon/summon collection system.

## Business Requirements

### User Stories

1. **As a user**, I want to record artifacts I own in the game so I can track my collection
2. **As a user**, I want to save artifact skill configurations so I can reference them when team building
3. **As a user**, I want to track multiple copies of the same artifact with different skill configurations
4. **As a user**, I want to equip artifacts from my collection to characters in parties
5. **As a user**, I want to quick-build artifacts directly in parties without adding to my collection
6. **As a user**, I want to see which characters have artifacts equipped in my parties

### Core Concepts

#### Collection vs Grid Artifacts
- **Collection Artifacts**: Represent artifacts in the user's inventory, independent of any party
- **Grid Artifacts**: Represent artifacts equipped to characters within a specific party

#### Artifact Types
- **Standard Artifacts**: Max level 150, 3 skill slots
- **Quirk Artifacts**: Max level 200, 4 skill slots (character-specific)

#### Skill System
- **Group I Skills**: Attack, HP, critical rate, etc. (max 2 per artifact)
- **Group II Skills**: Enmity, stamina, charge bar speed, etc. (max 1 per artifact)
- **Group III Skills**: Damage cap increases (max 1 per artifact)

Each skill has its own level that users can set when recording their artifacts.

#### Item Uniqueness Rules
- **Artifacts**: Multiple instances of the same artifact allowed per user, each with unique skill configurations
- **Grid Artifacts**: One artifact per character in a party

## Technical Design

### Database Schema

#### artifacts (Canonical Game Data)
```sql
- id: uuid (primary key)
- name_en: string (not null)
- name_jp: string (not null)
- series: integer (1=Ominous, 2=Saint, 3=Jinyao, etc.)
- weapon_specialty: integer (1=sabre, 2=dagger, etc.)
- rarity: integer (3=R, 4=SR, 5=SSR)
- is_quirk: boolean (default false)
- max_level: integer (default 5 for standard, 1 for quirk)
- created_at: timestamp
- updated_at: timestamp

Indexes:
- index on weapon_specialty
- index on rarity
- index on is_quirk
```

#### artifact_skills (Canonical Game Data)
```sql
- id: uuid (primary key)
- name_en: string (not null)
- name_jp: string (not null)
- skill_group: integer (1=Group I, 2=Group II, 3=Group III)
- effect_type: string (atk, hp, ca_dmg, skill_dmg, etc.)
- base_values: jsonb (array of possible starting values)
- growth_value: decimal (amount gained per level)
- max_level: integer (default 5)
- description_en: text
- description_jp: text
- created_at: timestamp
- updated_at: timestamp

Indexes:
- index on skill_group
- index on effect_type
```


#### collection_artifacts (User Collection)
```sql
- id: uuid (primary key)
- user_id: uuid (foreign key to users, not null)
- artifact_id: uuid (foreign key to artifacts, not null)
- level: integer (1-200)
- skill1_id: uuid (foreign key to artifact_skills)
- skill1_level: integer (1-15)
- skill2_id: uuid (foreign key to artifact_skills)
- skill2_level: integer (1-15)
- skill3_id: uuid (foreign key to artifact_skills)
- skill3_level: integer (1-15)
- skill4_id: uuid (foreign key to artifact_skills, optional for standard artifacts)
- skill4_level: integer (1-15, optional)
- created_at: timestamp
- updated_at: timestamp

Indexes:
- index on user_id
- index on artifact_id
- index on [user_id, artifact_id]
```


#### grid_artifacts (Party Equipment)
```sql
- id: uuid (primary key)
- party_id: uuid (foreign key to parties, not null)
- grid_character_id: uuid (foreign key to grid_characters, not null)
- collection_artifact_id: uuid (foreign key to collection_artifacts, optional)

# Quick-build fields (when not using collection)
- artifact_id: uuid (foreign key to artifacts, optional)
- level: integer (1-200)
- skill1_id: uuid (foreign key to artifact_skills)
- skill1_level: integer (1-15)
- skill2_id: uuid (foreign key to artifact_skills)
- skill2_level: integer (1-15)
- skill3_id: uuid (foreign key to artifact_skills)
- skill3_level: integer (1-15)
- skill4_id: uuid (foreign key to artifact_skills, optional)
- skill4_level: integer (1-15, optional)

- created_at: timestamp
- updated_at: timestamp

Indexes:
- unique index on grid_character_id (one artifact per character)
- index on party_id
- index on collection_artifact_id
- index on artifact_id
```


### Model Relationships

```ruby
# User model additions
has_many :collection_artifacts, dependent: :destroy

# Artifact model (canonical game data)
class Artifact < ApplicationRecord
  has_many :collection_artifacts, dependent: :restrict_with_error
  has_many :grid_artifacts, dependent: :restrict_with_error

  validates :name_en, :name_jp, presence: true
  validates :rarity, inclusion: { in: 3..5 }

  scope :standard, -> { where(is_quirk: false) }
  scope :quirk, -> { where(is_quirk: true) }

  def max_level
    is_quirk ? 200 : 150
  end

  def max_skill_slots
    is_quirk ? 4 : 3
  end
end

# ArtifactSkill model (canonical game data)
class ArtifactSkill < ApplicationRecord
  validates :name_en, :name_jp, presence: true
  validates :skill_group, inclusion: { in: 1..3 }
  validates :max_level, presence: true

  scope :group_i, -> { where(skill_group: 1) }
  scope :group_ii, -> { where(skill_group: 2) }
  scope :group_iii, -> { where(skill_group: 3) }
end

# CollectionArtifact model
class CollectionArtifact < ApplicationRecord
  belongs_to :user
  belongs_to :artifact
  belongs_to :skill1, class_name: 'ArtifactSkill', optional: true
  belongs_to :skill2, class_name: 'ArtifactSkill', optional: true
  belongs_to :skill3, class_name: 'ArtifactSkill', optional: true
  belongs_to :skill4, class_name: 'ArtifactSkill', optional: true

  has_one :grid_artifact, dependent: :nullify

  validates :level, numericality: {
    greater_than_or_equal_to: 1,
    less_than_or_equal_to: 200
  }
  validates :skill1_level, :skill2_level, :skill3_level,
            numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 15 },
            allow_nil: true
  validates :skill4_level,
            numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 15 },
            allow_nil: true

  # Validate skill4 only exists for quirk artifacts
  validate :skill4_only_for_quirk

  def skills
    [skill1, skill2, skill3, skill4].compact
  end

  private

  def skill4_only_for_quirk
    if skill4_id.present? && artifact && !artifact.is_quirk
      errors.add(:skill4_id, "can only be set for quirk artifacts")
    end
  end
end

# GridArtifact model
class GridArtifact < ApplicationRecord
  belongs_to :party
  belongs_to :grid_character
  belongs_to :collection_artifact, optional: true
  belongs_to :artifact, optional: true # For quick-build
  belongs_to :skill1, class_name: 'ArtifactSkill', optional: true
  belongs_to :skill2, class_name: 'ArtifactSkill', optional: true
  belongs_to :skill3, class_name: 'ArtifactSkill', optional: true
  belongs_to :skill4, class_name: 'ArtifactSkill', optional: true

  validates :grid_character_id, uniqueness: true
  validate :validate_artifact_source

  def from_collection?
    collection_artifact_id.present?
  end

  def artifact_details
    if from_collection?
      collection_artifact.artifact
    else
      artifact
    end
  end

  def skills
    if from_collection?
      collection_artifact.skills
    else
      [skill1, skill2, skill3, skill4].compact
    end
  end

  private

  def validate_artifact_source
    if collection_artifact_id.blank? && artifact_id.blank?
      errors.add(:base, "Must specify either collection artifact or quick-build artifact")
    end

    if collection_artifact_id.present? && artifact_id.present? && !from_collection?
      errors.add(:base, "Cannot specify both collection and quick-build artifact")
    end
  end
end

# GridCharacter model additions
has_one :grid_artifact, dependent: :destroy

# Party model additions
has_many :grid_artifacts, dependent: :destroy
```

### API Design

#### Endpoints

##### Collection Artifacts
```
GET    /api/v1/collection/artifacts
  Query params: page, limit, artifact_id (filter)
  Response: Paginated list of user's artifacts

GET    /api/v1/collection/artifacts/:id
  Response: Single collection artifact details

POST   /api/v1/collection/artifacts
  Body: artifact_id, level, skill1_id, skill1_level, skill2_id, skill2_level, etc.
  Response: Created collection artifact

PUT    /api/v1/collection/artifacts/:id
  Body: Updated fields
  Response: Updated collection artifact

DELETE /api/v1/collection/artifacts/:id
  Response: Success/error status
```

##### Grid Artifacts (Party Equipment)
```
GET    /api/v1/parties/:party_id/grid_artifacts
  Response: List of artifacts equipped in party

POST   /api/v1/parties/:party_id/grid_artifacts
  Body: { grid_character_id, collection_artifact_id } OR
        { grid_character_id, artifact_id, level, skills... } (quick-build)
  Response: Created grid artifact

PUT    /api/v1/parties/:party_id/grid_artifacts/:id
  Body: Updated artifact reference or properties
  Response: Updated grid artifact

DELETE /api/v1/parties/:party_id/grid_artifacts/:id
  Response: Success/error status
```

##### Canonical Data Endpoints
```
GET    /api/v1/artifacts
  Query: is_quirk?, page, limit
  Response: List of all artifacts

GET    /api/v1/artifacts/:id
  Response: Artifact details

GET    /api/v1/artifact_skills
  Query: skill_group?, page, limit
  Response: List of all artifact skills

GET    /api/v1/artifact_skills/:id
  Response: Skill details
```

##### Collection Management
```
GET    /api/v1/users/:user_id/collection/artifacts
  Response: View another user's artifact collection (respects privacy settings)

GET    /api/v1/collection/statistics
  Response: {
    total_artifacts: 50,
    breakdown_by_rarity: {standard: 45, quirk: 5},
    breakdown_by_level: {...}
  }
```

### Security Considerations

1. **Authorization**: Collection management endpoints require authentication
2. **Ownership**: Users can only modify their own collection
3. **Privacy Controls**: Respect user's collection_privacy settings when viewing collections
4. **Validation**: Strict validation of skill combinations and levels
5. **Rate Limiting**: Standard rate limiting on all collection endpoints

### Performance Considerations

1. **Eager Loading**: Include skills and artifact data in collection queries
2. **Batch Operations**: Support bulk artifact operations for imports
3. **Indexed Queries**: Proper indexes on frequently filtered columns
4. **Pagination**: Mandatory pagination for collection endpoints

## Implementation Phases

### Phase 1: Core Models and Database
- Create migrations for artifacts, skills, and collections
- Implement Artifact and ArtifactSkill models
- Implement CollectionArtifact model
- Seed canonical artifact and skill data

### Phase 2: API Controllers and Blueprints
- Implement collection artifacts CRUD controller
- Create artifact blueprints
- Add authentication and authorization
- Write controller specs

### Phase 3: Grid Integration
- Implement GridArtifact model
- Create grid artifacts controller
- Add artifact support to party endpoints
- Integrate with existing party system

### Phase 4: Frontend Integration
- Update frontend models and types
- Create artifact management UI
- Add artifact selection in party builder
- Implement collection views

## Success Metrics

1. **Performance**: All endpoints respond within 200ms for standard operations
2. **Reliability**: 99.9% uptime for artifact services
3. **User Adoption**: 50% of active users use artifact tracking within 3 months
4. **Data Integrity**: Zero data loss incidents