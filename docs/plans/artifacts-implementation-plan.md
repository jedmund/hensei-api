# Artifacts Implementation Plan

## Overview

This document outlines the implementation plan for adding Artifacts to the hensei-api. Artifacts are equipment items that can be attached to characters, providing four skill bonuses. They have element and proficiency requirements that must match the equipped character.

## Key Design Decisions

Based on requirements discussion:

1. **Skill definitions**: Hardcoded in model constants (similar to rings)
2. **Base entity**: Create `artifacts` table for the 30 standard + 5 quirk artifact types
3. **User input**: Direct value input with validation against valid formulas
4. **Collection model**: Multiple artifacts of same type allowed per user
5. **Grid linkage**: GridArtifact belongs_to GridCharacter
6. **Quirk skills**: Not stored in database - frontend handles display based on artifact name
7. **Naming**: Add optional nickname field to collection_artifacts

---

## Data Model

### 1. `artifacts` Table (Base Entity)

Stores the 35 artifact types (30 standard + 5 quirk). This is static reference data.

```ruby
create_table :artifacts, id: :uuid do |t|
  t.string :granblue_id, null: false      # Game's internal ID
  t.string :name_en, null: false          # English name
  t.string :name_jp                       # Japanese name
  t.integer :proficiency, null: false     # 1-10 (sabre, dagger, spear, axe, staff, gun, melee, bow, harp, katana)
  t.integer :rarity, null: false          # 0 = standard, 1 = quirk
  t.integer :style                        # 1-3 for standard artifacts (Ominous/Saint/Jinyao style)

  # No timestamps - static reference data
end

add_index :artifacts, :granblue_id, unique: true
add_index :artifacts, :proficiency
add_index :artifacts, :rarity
```

**Notes:**
- Standard artifacts have 3 styles per proficiency (30 total)
- Quirk artifacts (5 total) have `rarity: 1` and `style: nil`
- Images will be stored on CDN, derived from granblue_id

### 2. `collection_artifacts` Table

User's artifact inventory. Unlike other collection items, users can own multiple artifacts of the same type.

```ruby
create_table :collection_artifacts, id: :uuid do |t|
  t.references :user, type: :uuid, null: false, foreign_key: true
  t.references :artifact, type: :uuid, null: false, foreign_key: true

  # Artifact properties
  t.integer :element, null: false         # 1-6 (fire, water, earth, wind, light, dark)
  t.integer :level, null: false, default: 1  # 1-5 for standard, always 1 for quirk
  t.string :nickname                      # Optional user label

  # Skills (JSONB) - each contains: { modifier: int, strength: value, level: int }
  # For standard artifacts: modifier = skill ID, strength = level 1 base value, level = 1-5
  # For quirk artifacts: these are nil (skills are fixed and determined by artifact name)
  t.jsonb :skill1, default: {}, null: false  # Group I skill
  t.jsonb :skill2, default: {}, null: false  # Group I skill
  t.jsonb :skill3, default: {}, null: false  # Group II skill
  t.jsonb :skill4, default: {}, null: false  # Group III skill

  t.timestamps
end

add_index :collection_artifacts, :user_id
add_index :collection_artifacts, [:user_id, :artifact_id]
add_index :collection_artifacts, :element
```

**Skill JSONB Structure:**
```json
{
  "modifier": 1,      // Skill type ID within the group
  "strength": 1320,   // Level 1 base value (one of 5 valid values per skill)
  "level": 3          // Skill level 1-5
}
```

**Constraint:** Sum of all 4 skill levels must equal (artifact_level + 3). At level 1, all skills are level 1 (sum=4). At level 5, skills sum to 8.

### 3. `grid_artifacts` Table

Artifacts equipped to characters within a party.

```ruby
create_table :grid_artifacts, id: :uuid do |t|
  t.references :grid_character, type: :uuid, null: false, foreign_key: true
  t.references :artifact, type: :uuid, null: false, foreign_key: true

  # Artifact properties (same as collection_artifacts)
  t.integer :element, null: false
  t.integer :level, null: false, default: 1

  t.jsonb :skill1, default: {}, null: false
  t.jsonb :skill2, default: {}, null: false
  t.jsonb :skill3, default: {}, null: false
  t.jsonb :skill4, default: {}, null: false

  t.timestamps
end

add_index :grid_artifacts, :grid_character_id, unique: true  # One artifact per character
add_index :grid_artifacts, :artifact_id
```

**Validation:** The artifact's element and proficiency must match the character's element and one of their proficiencies.

---

## Skill Groups Definition

Hardcoded in model as constants. Each skill has:
- `name`: Display name
- `base_values`: Array of 5 valid level 1 values
- `growth`: Amount added per level
- `value_type`: `:integer`, `:percent`, or `:percent_decimal` (for values like 0.5%)

### Group I Skills (Slots 1 & 2)

| ID | Name | Base Values | Growth | Type |
|----|------|-------------|--------|------|
| 1 | ATK | 1320, 1440, 1560, 1680, 1800 | +300 | integer |
| 2 | HP | 660, 720, 780, 840, 900 | +150 | integer |
| 3 | C.A. DMG | 13.2, 14.4, 15.6, 16.8, 18.0 | +3 | percent |
| 4 | Skill DMG | 13.2, 14.4, 15.6, 16.8, 18.0 | +3 | percent |
| 5 | Elemental ATK | 8.8, 9.6, 10.4, 11.2, 12.0 | +2 | percent |
| 6 | Critical Hit Rate | 13.2, 14.4, 15.6, 16.8, 18.0 | +3 | percent |
| 7 | Double Attack Rate | 6.6, 7.2, 7.8, 8.4, 9.0 | +1.5 | percent |
| 8 | Triple Attack Rate | 4.4, 4.8, 5.2, 5.6, 6.0 | +1 | percent |
| 9 | DEF | 8.8, 9.6, 10.4, 11.2, 12.0 | +2 | percent |
| 10 | Superior Element Reduction | 4.4, 4.8, 5.2, 5.6, 6.0 | +1 | percent |
| 11 | Dodge Rate | 4.4, 4.8, 5.2, 5.6, 6.0 | +1 | percent |
| 12 | Healing | 13.2, 14.4, 15.6, 16.8, 18.0 | +3 | percent |
| 13 | Debuff Success Rate | 6.6, 7.2, 7.8, 8.4, 9.0 | +1.5 | percent |
| 14 | Debuff Resistance | 6.6, 7.2, 7.8, 8.4, 9.0 | +1.5 | percent |

### Group II Skills (Slot 3)

| ID | Name | Base Values | Growth | Type |
|----|------|-------------|--------|------|
| 1 | N.A. DMG Cap | 2.2, 2.4, 2.6, 2.8, 3.0 | +0.5 | percent |
| 2 | Skill DMG Cap | 8.8, 9.6, 10.4, 11.2, 12.0 | +2 | percent |
| 3 | C.A. DMG Cap | 6.6, 7.2, 7.8, 8.4, 9.0 | +1.5 | percent |
| 4 | Special C.A. DMG Cap | 4.4, 4.8, 5.2, 5.6, 6.0 | +1 | percent |
| 5 | Boost DMG cap for critical hits | 2.2, 2.4, 2.6, 2.8, 3.0 | +0.5 | percent |
| 6 | N.A. DMG cap boost (80%/60% penalty) | 4.4, 4.8, 5.2, 5.6, 6.0 | +1 | percent |
| 7 | Skill DMG cap boost (20%/60% penalty) | 17.6, 19.2, 20.8, 22.4, 24.0 | +4 | percent |
| 8 | C.A. DMG cap boost (20%/80% penalty) | 13.2, 14.4, 15.6, 16.8, 18.0 | +3 | percent |
| 9 | Supplemental N.A. DMG | 8800, 9600, 10400, 11200, 12000 | +2000 | integer |
| 10 | Supplemental Skill DMG | 11000, 12000, 13000, 14000, 15000 | +2500 | integer |
| 11 | Supplemental C.A. DMG | 110000, 120000, 130000, 140000, 150000 | +25000 | integer |
| 12 | Chain DMG Amplify | 6.6, 7.2, 7.8, 8.4, 9.0 | +1.5 | percent |
| 13 | Boost TA rate when ≥50% HP | 6.6, 7.2, 7.8, 8.4, 9.0 | +1.5 | percent |
| 14 | Amplify DMG at 100% HP | 2.2, 2.4, 2.6, 2.8, 3.0 | +0.5 | percent |
| 15 | Max HP boost (70% DEF penalty) | 8.8, 9.6, 10.4, 11.2, 12.0 | +2 | percent |
| 16 | DMG reduction when ≤50% HP | 8.8, 9.6, 10.4, 11.2, 12.0 | +2 | percent |
| 17 | Regeneration | 440, 480, 520, 560, 600 | +100 | integer |
| 18 | Turn-Based DMG Reduction | 8.8, 9.6, 10.4, 11.2, 12.0 | +2 | percent |
| 19 | Chance to remove 1 debuff | 20 | +20 | percent |
| 20 | Chance to cancel dispels | 20 | +20 | percent |

**Note:** Skills 19 and 20 have only one base value (20%), not 5.

### Group III Skills (Slot 4)

Group III has ~25+ skills with varied mechanics. The growth values can be positive or negative (e.g., "after using skills x times" decreases the required count with levels).

| ID | Name | Base Value | Growth | Notes |
|----|------|------------|--------|-------|
| 1 | Battle start: DMG Mitigation | 1000 | +1000 | integer |
| 2 | Battle start: Random buff(s) | 1 | +1 | count |
| 3 | HP consumed + DMG Cap after 3T | 10 | +10 | percent |
| 4 | On knockout: Ally buffs | 1 | +1 | count |
| 5 | On switch to main: DMG Amplified | 3 | +3 | percent |
| 6 | Foe ≤50% HP: Restore HP | 2000 | +2000 | integer |
| 7 | Skill 1 CD cut + HP consume | 30 | -6 | percent (decreasing) |
| 8 | Debuff skill: Amplify foe DMG taken | 4 | +4 | percent |
| 9 | Healing skill: Bonus DMG to next ally | 4 | +4 | percent |
| 10 | DMG Cap stackable after X skills | 5 | -1 | count (decreasing) |
| 11 | After 10+ turn skill: DMG Amplified | 2 | +2 | percent |
| 12 | Linked skill CD cut after X uses | 8 | -1 | count (decreasing) |
| 13 | Supplemental DMG based on charge bar | 5000 | +5000 | integer |
| 14 | No attack: Random stackable buff(s) | 1 | +1 | count |
| 15 | Chance to remove foe buffs | 1 | +1 | percent |
| 16 | Chance to progress turn by 5 | 0.2 | +0.2 | percent |
| 17 | Shield every 5 turns | 1000 | +500 | integer |
| 18 | Chance for 6-hit Flurry | 1 | +1 | percent |
| 19 | Bonus DMG after X enemy hits | 7 | -1 | count (decreasing) |
| 20 | 3-hit Flurry after X hits | 200 | -25 | count (decreasing) |
| 21 | Plain DMG based on HP lost | 10 | +10 | multiplier |
| 22 | Supplemental Skill DMG after X skill DMG | 40000000 | -5000000 | integer (decreasing) |
| 23 | Single attack: Random buff(s) | 1 | +1 | count |
| 24 | Potion use: Fated Chain boost | 3 | +3 | percent |
| 25 | Foe ≤3 debuffs: Armored | 5 | +5 | percent |
| 26 | Sub ally: Debuff foes every X turns | 7 | -1 | count (decreasing) |
| 27 | Boost EXP earned | 1 | +1 | percent |
| 28 | Boost item drop rate | 0.5 | +0.5 | percent |
| 29 | Chance to find earrings | ? | ? | unknown |

---

## Model Implementation

### Artifact Model

```ruby
# app/models/artifact.rb
class Artifact < ApplicationRecord
  # Enums
  enum :proficiency, {
    sabre: 1, dagger: 2, spear: 3, axe: 4, staff: 5,
    gun: 6, melee: 7, bow: 8, harp: 9, katana: 10
  }

  enum :rarity, { standard: 0, quirk: 1 }

  # Associations
  has_many :collection_artifacts, dependent: :restrict_with_error
  has_many :grid_artifacts, dependent: :restrict_with_error

  # Validations
  validates :granblue_id, presence: true, uniqueness: true
  validates :name_en, presence: true
  validates :proficiency, presence: true
  validates :rarity, presence: true
  validates :style, presence: true, inclusion: { in: 1..3 }, if: :standard?
  validates :style, absence: true, if: :quirk?

  # Scopes
  scope :standard_artifacts, -> { where(rarity: :standard) }
  scope :quirk_artifacts, -> { where(rarity: :quirk) }
  scope :by_proficiency, ->(prof) { where(proficiency: prof) }
end
```

### CollectionArtifact Model

```ruby
# app/models/collection_artifact.rb
class CollectionArtifact < ApplicationRecord
  include ArtifactSkillValidations

  # Associations
  belongs_to :user
  belongs_to :artifact

  # Enums
  enum :element, {
    fire: 1, water: 2, earth: 3, wind: 4, light: 5, dark: 6
  }

  # Validations
  validates :element, presence: true
  validates :level, presence: true, inclusion: { in: 1..5 }
  validates :nickname, length: { maximum: 50 }, allow_blank: true

  validate :validate_skill_levels_sum
  validate :validate_skills_for_standard_artifacts
  validate :validate_quirk_artifact_constraints

  # Scopes
  scope :by_element, ->(el) { where(element: el) }
  scope :by_artifact, ->(artifact_id) { where(artifact_id: artifact_id) }
  scope :by_proficiency, ->(prof) { joins(:artifact).where(artifacts: { proficiency: prof }) }

  private

  def validate_skill_levels_sum
    return if artifact&.quirk?

    total = [skill1, skill2, skill3, skill4].sum { |s| s['level'].to_i }
    expected = level + 3

    unless total == expected
      errors.add(:base, "Skill levels must sum to #{expected} for artifact level #{level}")
    end
  end

  def validate_quirk_artifact_constraints
    return unless artifact&.quirk?

    errors.add(:level, "must be 1 for quirk artifacts") unless level == 1

    # Quirk artifacts don't store skills
    [skill1, skill2, skill3, skill4].each_with_index do |skill, idx|
      unless skill.blank? || skill == {}
        errors.add(:"skill#{idx + 1}", "must be empty for quirk artifacts")
      end
    end
  end
end
```

### GridArtifact Model

```ruby
# app/models/grid_artifact.rb
class GridArtifact < ApplicationRecord
  include ArtifactSkillValidations

  # Associations
  belongs_to :grid_character
  belongs_to :artifact

  has_one :party, through: :grid_character
  has_one :character, through: :grid_character

  # Enums
  enum :element, {
    fire: 1, water: 2, earth: 3, wind: 4, light: 5, dark: 6
  }

  # Validations
  validates :element, presence: true
  validates :level, presence: true, inclusion: { in: 1..5 }
  validates :grid_character_id, uniqueness: { message: "already has an artifact equipped" }

  validate :validate_skill_levels_sum
  validate :validate_character_compatibility
  validate :validate_quirk_artifact_constraints

  private

  def validate_character_compatibility
    return unless grid_character&.character && artifact

    char = grid_character.character

    # Check element compatibility (skip for characters with variable elements like Lyria)
    unless char.any_element?
      unless char.element == element
        errors.add(:element, "must match character's element")
      end
    end

    # Check proficiency compatibility
    char_proficiencies = [char.proficiency1, char.proficiency2].compact
    unless char_proficiencies.include?(artifact.proficiency)
      errors.add(:artifact, "proficiency must match one of the character's proficiencies")
    end
  end
end
```

### Shared Skill Validation Concern

```ruby
# app/models/concerns/artifact_skill_validations.rb
module ArtifactSkillValidations
  extend ActiveSupport::Concern

  ELEMENT_ENUM = { fire: 1, water: 2, earth: 3, wind: 4, light: 5, dark: 6 }.freeze

  # Group I skills (slots 1 & 2)
  GROUP_I_SKILLS = {
    1 => { name: 'ATK', base_values: [1320, 1440, 1560, 1680, 1800], growth: 300, type: :integer },
    2 => { name: 'HP', base_values: [660, 720, 780, 840, 900], growth: 150, type: :integer },
    3 => { name: 'C.A. DMG', base_values: [13.2, 14.4, 15.6, 16.8, 18.0], growth: 3, type: :percent },
    4 => { name: 'Skill DMG', base_values: [13.2, 14.4, 15.6, 16.8, 18.0], growth: 3, type: :percent },
    5 => { name: 'Elemental ATK', base_values: [8.8, 9.6, 10.4, 11.2, 12.0], growth: 2, type: :percent },
    6 => { name: 'Critical Hit Rate', base_values: [13.2, 14.4, 15.6, 16.8, 18.0], growth: 3, type: :percent },
    7 => { name: 'Double Attack Rate', base_values: [6.6, 7.2, 7.8, 8.4, 9.0], growth: 1.5, type: :percent },
    8 => { name: 'Triple Attack Rate', base_values: [4.4, 4.8, 5.2, 5.6, 6.0], growth: 1, type: :percent },
    9 => { name: 'DEF', base_values: [8.8, 9.6, 10.4, 11.2, 12.0], growth: 2, type: :percent },
    10 => { name: 'Superior Element Reduction', base_values: [4.4, 4.8, 5.2, 5.6, 6.0], growth: 1, type: :percent },
    11 => { name: 'Dodge Rate', base_values: [4.4, 4.8, 5.2, 5.6, 6.0], growth: 1, type: :percent },
    12 => { name: 'Healing', base_values: [13.2, 14.4, 15.6, 16.8, 18.0], growth: 3, type: :percent },
    13 => { name: 'Debuff Success Rate', base_values: [6.6, 7.2, 7.8, 8.4, 9.0], growth: 1.5, type: :percent },
    14 => { name: 'Debuff Resistance', base_values: [6.6, 7.2, 7.8, 8.4, 9.0], growth: 1.5, type: :percent }
  }.freeze

  # Group II skills (slot 3)
  GROUP_II_SKILLS = {
    1 => { name: 'N.A. DMG Cap', base_values: [2.2, 2.4, 2.6, 2.8, 3.0], growth: 0.5, type: :percent },
    2 => { name: 'Skill DMG Cap', base_values: [8.8, 9.6, 10.4, 11.2, 12.0], growth: 2, type: :percent },
    3 => { name: 'C.A. DMG Cap', base_values: [6.6, 7.2, 7.8, 8.4, 9.0], growth: 1.5, type: :percent },
    4 => { name: 'Special C.A. DMG Cap', base_values: [4.4, 4.8, 5.2, 5.6, 6.0], growth: 1, type: :percent },
    5 => { name: 'Boost DMG cap for critical hits', base_values: [2.2, 2.4, 2.6, 2.8, 3.0], growth: 0.5, type: :percent },
    6 => { name: 'N.A. DMG cap boost (penalty)', base_values: [4.4, 4.8, 5.2, 5.6, 6.0], growth: 1, type: :percent },
    7 => { name: 'Skill DMG cap boost (penalty)', base_values: [17.6, 19.2, 20.8, 22.4, 24.0], growth: 4, type: :percent },
    8 => { name: 'C.A. DMG cap boost (penalty)', base_values: [13.2, 14.4, 15.6, 16.8, 18.0], growth: 3, type: :percent },
    9 => { name: 'Supplemental N.A. DMG', base_values: [8800, 9600, 10400, 11200, 12000], growth: 2000, type: :integer },
    10 => { name: 'Supplemental Skill DMG', base_values: [11000, 12000, 13000, 14000, 15000], growth: 2500, type: :integer },
    11 => { name: 'Supplemental C.A. DMG', base_values: [110000, 120000, 130000, 140000, 150000], growth: 25000, type: :integer },
    12 => { name: 'Chain DMG Amplify', base_values: [6.6, 7.2, 7.8, 8.4, 9.0], growth: 1.5, type: :percent },
    13 => { name: 'Boost TA rate when ≥50% HP', base_values: [6.6, 7.2, 7.8, 8.4, 9.0], growth: 1.5, type: :percent },
    14 => { name: 'Amplify DMG at 100% HP', base_values: [2.2, 2.4, 2.6, 2.8, 3.0], growth: 0.5, type: :percent },
    15 => { name: 'Max HP boost (DEF penalty)', base_values: [8.8, 9.6, 10.4, 11.2, 12.0], growth: 2, type: :percent },
    16 => { name: 'DMG reduction when ≤50% HP', base_values: [8.8, 9.6, 10.4, 11.2, 12.0], growth: 2, type: :percent },
    17 => { name: 'Regeneration', base_values: [440, 480, 520, 560, 600], growth: 100, type: :integer },
    18 => { name: 'Turn-Based DMG Reduction', base_values: [8.8, 9.6, 10.4, 11.2, 12.0], growth: 2, type: :percent },
    19 => { name: 'Chance to remove 1 debuff', base_values: [20], growth: 20, type: :percent },
    20 => { name: 'Chance to cancel dispels', base_values: [20], growth: 20, type: :percent }
  }.freeze

  # Group III skills (slot 4) - simplified, full list in implementation
  GROUP_III_SKILLS = {
    1 => { name: 'Battle start: DMG Mitigation', base_values: [1000], growth: 1000, type: :integer },
    2 => { name: 'Battle start: Random buff(s)', base_values: [1], growth: 1, type: :count },
    3 => { name: 'HP consumed + DMG Cap after 3T', base_values: [10], growth: 10, type: :percent },
    4 => { name: 'On knockout: Ally buffs', base_values: [1], growth: 1, type: :count },
    5 => { name: 'On switch to main: DMG Amplified', base_values: [3], growth: 3, type: :percent },
    6 => { name: 'Foe ≤50% HP: Restore HP', base_values: [2000], growth: 2000, type: :integer },
    7 => { name: 'Skill 1 CD cut + HP consume', base_values: [30], growth: -6, type: :percent },
    8 => { name: 'Debuff skill: Amplify foe DMG taken', base_values: [4], growth: 4, type: :percent },
    9 => { name: 'Healing skill: Bonus DMG to next ally', base_values: [4], growth: 4, type: :percent },
    10 => { name: 'DMG Cap stackable after X skills', base_values: [5], growth: -1, type: :count },
    11 => { name: 'After 10+ turn skill: DMG Amplified', base_values: [2], growth: 2, type: :percent },
    12 => { name: 'Linked skill CD cut after X uses', base_values: [8], growth: -1, type: :count },
    13 => { name: 'Supplemental DMG based on charge bar', base_values: [5000], growth: 5000, type: :integer },
    14 => { name: 'No attack: Random stackable buff(s)', base_values: [1], growth: 1, type: :count },
    15 => { name: 'Chance to remove foe buffs', base_values: [1], growth: 1, type: :percent },
    16 => { name: 'Chance to progress turn by 5', base_values: [0.2], growth: 0.2, type: :percent },
    17 => { name: 'Shield every 5 turns', base_values: [1000], growth: 500, type: :integer },
    18 => { name: 'Chance for 6-hit Flurry', base_values: [1], growth: 1, type: :percent },
    19 => { name: 'Bonus DMG after X enemy hits', base_values: [7], growth: -1, type: :count },
    20 => { name: '3-hit Flurry after X hits', base_values: [200], growth: -25, type: :count },
    21 => { name: 'Plain DMG based on HP lost', base_values: [10], growth: 10, type: :multiplier },
    22 => { name: 'Supplemental Skill DMG after X skill DMG', base_values: [40000000], growth: -5000000, type: :integer },
    23 => { name: 'Single attack: Random buff(s)', base_values: [1], growth: 1, type: :count },
    24 => { name: 'Potion use: Fated Chain boost', base_values: [3], growth: 3, type: :percent },
    25 => { name: 'Foe ≤3 debuffs: Armored', base_values: [5], growth: 5, type: :percent },
    26 => { name: 'Sub ally: Debuff foes every X turns', base_values: [7], growth: -1, type: :count },
    27 => { name: 'Boost EXP earned', base_values: [1], growth: 1, type: :percent },
    28 => { name: 'Boost item drop rate', base_values: [0.5], growth: 0.5, type: :percent },
    29 => { name: 'Chance to find earrings', base_values: [nil], growth: nil, type: :unknown }
  }.freeze

  included do
    validate :validate_skill1_group_i
    validate :validate_skill2_group_i
    validate :validate_skill3_group_ii
    validate :validate_skill4_group_iii
  end

  private

  def validate_skill_in_group(skill_data, group, slot_name)
    return if skill_data.blank? || skill_data == {}
    return if artifact&.quirk?

    modifier = skill_data['modifier']
    strength = skill_data['strength']
    level = skill_data['level']

    unless modifier && strength && level
      errors.add(slot_name, "must have modifier, strength, and level")
      return
    end

    skill_def = group[modifier]
    unless skill_def
      errors.add(slot_name, "has invalid modifier #{modifier}")
      return
    end

    unless (1..5).include?(level)
      errors.add(slot_name, "level must be between 1 and 5")
      return
    end

    # Validate strength is a valid base value for this skill
    unless skill_def[:base_values].include?(strength) || skill_def[:base_values] == [nil]
      errors.add(slot_name, "has invalid base strength #{strength}")
    end
  end

  def validate_skill1_group_i
    validate_skill_in_group(skill1, GROUP_I_SKILLS, :skill1)
  end

  def validate_skill2_group_i
    validate_skill_in_group(skill2, GROUP_I_SKILLS, :skill2)
  end

  def validate_skill3_group_ii
    validate_skill_in_group(skill3, GROUP_II_SKILLS, :skill3)
  end

  def validate_skill4_group_iii
    validate_skill_in_group(skill4, GROUP_III_SKILLS, :skill4)
  end
end
```

---

## API Endpoints

### Artifacts (Base Entity - Read Only)

```
GET /api/v1/artifacts              # List all artifact types
GET /api/v1/artifacts/:id          # Get single artifact type
```

### Collection Artifacts

```
GET    /api/v1/users/:user_id/collection/artifacts    # List user's artifacts
POST   /api/v1/users/:user_id/collection/artifacts    # Add artifact to collection
GET    /api/v1/collection/artifacts/:id               # Get single collection artifact
PATCH  /api/v1/collection/artifacts/:id               # Update collection artifact
DELETE /api/v1/collection/artifacts/:id               # Remove from collection

# Batch operations
POST   /api/v1/users/:user_id/collection/artifacts/batch  # Add multiple artifacts
```

### Grid Artifacts (via Grid Characters)

```
POST   /api/v1/parties/:party_id/characters/:character_id/artifact  # Equip artifact
PATCH  /api/v1/parties/:party_id/characters/:character_id/artifact  # Update equipped artifact
DELETE /api/v1/parties/:party_id/characters/:character_id/artifact  # Unequip artifact
```

---

## Implementation Order

### Phase 1: Database & Models
1. Create migration for `artifacts` table
2. Create migration for `collection_artifacts` table
3. Create migration for `grid_artifacts` table
4. Implement `Artifact` model
5. Implement `ArtifactSkillValidations` concern
6. Implement `CollectionArtifact` model
7. Implement `GridArtifact` model
8. Add associations to `User` and `GridCharacter` models
9. Seed artifact data (30 standard + 5 quirk)

### Phase 2: Blueprints
1. Create `ArtifactBlueprint`
2. Create `CollectionArtifactBlueprint`
3. Create `GridArtifactBlueprint`
4. Update `GridCharacterBlueprint` to include artifact
5. Update `PartyBlueprint` to include artifacts

### Phase 3: Controllers
1. Create `ArtifactsController` (index, show)
2. Create `CollectionArtifactsController` (full CRUD + batch)
3. Update `GridCharactersController` to handle artifact operations
4. Add routes

### Phase 4: Testing
1. Model specs for all new models
2. Request specs for all new endpoints
3. Validation specs for skill constraints

---

## Seed Data

### Standard Artifacts (30 total)

| Proficiency | Style 1 (Ominous) | Style 2 (Saint) | Style 3 (Jinyao) |
|-------------|-------------------|-----------------|------------------|
| Sabre | Ominous Amulet | Couronne Sainte | Jinyao Yushi |
| Dagger | Ominous Ring | Jaseron Saint | Jinyao Mianju |
| Spear | Ominous Goblet | Casque Saint | Jinyao Qizhi |
| Axe | Ominous Horn | Armure Sainte | Jinyao Yaodai |
| Staff | Ominous Totem | Robe Sainte | Jinyao Mingjing |
| Gun | Ominous Pendant | Lunettes Saintes | Jinyao Wangjing |
| Melee | Ominous Bangle | Bottes Saintes | Jinyao Mianzhao |
| Bow | Ominous Pheon | Chapeau Saint | Jinyao Xiongjia |
| Harp | Ominous Whistle | Boite a Musique Sainte | Jinyao Tongluo |
| Katana | Ominous Stone | Capuchon Saint | Jinyao Xianglu |

### Quirk Artifacts (5 total)

| Name | Skills (handled by frontend) |
|------|------------------------------|
| Fantosmik Creste | Crest-based damage amplification |
| Fantosmik Fengtooth | CA-focused with HP consumption |
| Fantosmik Gemme | Shield and Guts mechanics |
| Fantosmik Lanterne | Universal weapon skill compatibility |
| Fantosmik Maylet | Random stat changes |

---

## Open Questions / Future Considerations

1. **Character any_element flag**: Need to verify how this is currently stored in Character model for Lyria-type characters
2. **Image URLs**: Confirm CDN path pattern for artifact images
3. **Granblue IDs**: Need to determine the actual game IDs for each artifact type
4. **Frontend coordination**: Quirk artifact skill display will need frontend implementation
5. **Migration strategy**: Consider data_migrate for seeding artifacts to ensure proper ordering
