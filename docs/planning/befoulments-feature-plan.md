# Befoulments & WeaponStatModifier Consolidation

## Overview

Implement Befoulments (魔蝕) and consolidate with AX skills using a new `WeaponStatModifier` table.

### Terminology
- **Odiant (禁禍武器)** = A weapon series that has befoulments instead of AX skills
- **Befoulments (魔蝕)** = Negative stat augments that appear on Odiant weapons
- **Exorcism Level (退魔Lv)** = Level 0-5 that reduces befoulment strength

**Key insight:** `augment_skill_info` contains:
- **AX skills** for regular weapons (`is_odiant_weapon: false`)
- **Befoulments** for Odiant weapons (`is_odiant_weapon: true`)

They are mutually exclusive - a weapon has either AX skills OR befoulments, never both.

---

## Database Schema

### 1. New Table: `weapon_stat_modifiers`

Centralized definition of all weapon stat modifiers (AX skills + befoulments):

```ruby
create_table :weapon_stat_modifiers do |t|
  t.string :slug, null: false, index: { unique: true }  # 'ax_atk', 'befoul_def_down'
  t.string :name_en, null: false
  t.string :name_jp
  t.string :category, null: false      # 'ax' or 'befoulment'
  t.string :stat                       # 'atk', 'def', 'da_ta', 'ca_dmg', 'hp', 'dot', etc.
  t.integer :polarity, default: 1      # 1 = buff, -1 = debuff
  t.string :suffix                     # '%' for percentages, nil for flat values
  t.float :base_min                    # Known min initial value (informational)
  t.float :base_max                    # Known max initial value (informational)
  t.integer :game_skill_id             # Maps to game's skill_id for import
  t.timestamps
end
```

**Icon convention:** Frontend derives icon path from `slug`:
- `ax_atk` → `weapon-stat-modifier/ax_atk.png`
- `befoul_def_down` → `weapon-stat-modifier/befoul_def_down.png`

Rename game icons (e.g., `ex_skill_def_down` → `befoul_def_down`) to match slugs.

### 2. Refactor AX & Add Befoulment Columns (Foreign Keys)

Replace raw integer `ax_modifier1/2` with foreign keys, and add befoulment FK:

```ruby
# collection_weapons
# Remove old integer columns
remove_column :collection_weapons, :ax_modifier1, :integer
remove_column :collection_weapons, :ax_modifier2, :integer

# Add FK columns referencing weapon_stat_modifiers
add_reference :collection_weapons, :ax_modifier1, foreign_key: { to_table: :weapon_stat_modifiers }
add_reference :collection_weapons, :ax_modifier2, foreign_key: { to_table: :weapon_stat_modifiers }
add_reference :collection_weapons, :befoulment_modifier, foreign_key: { to_table: :weapon_stat_modifiers }
add_column :collection_weapons, :befoulment_strength, :float
add_column :collection_weapons, :exorcism_level, :integer, default: 0

# grid_weapons - same pattern
add_reference :grid_weapons, :ax_modifier1, foreign_key: { to_table: :weapon_stat_modifiers }
add_reference :grid_weapons, :ax_modifier2, foreign_key: { to_table: :weapon_stat_modifiers }
add_reference :grid_weapons, :befoulment_modifier, foreign_key: { to_table: :weapon_stat_modifiers }
add_column :grid_weapons, :befoulment_strength, :float
add_column :grid_weapons, :exorcism_level, :integer, default: 0
```

### 2b. Data Migration for Existing AX Skills

Migrate existing `ax_modifier1/2` integer values to FK references:

```ruby
# Run after weapon_stat_modifiers table is seeded
CollectionWeapon.where.not(ax_modifier1: nil).find_each do |cw|
  modifier = WeaponStatModifier.find_by(game_skill_id: cw.ax_modifier1)
  cw.update_columns(ax_modifier1_id: modifier&.id) if modifier
end

CollectionWeapon.where.not(ax_modifier2: nil).find_each do |cw|
  modifier = WeaponStatModifier.find_by(game_skill_id: cw.ax_modifier2)
  cw.update_columns(ax_modifier2_id: modifier&.id) if modifier
end

# Same for GridWeapon
```

**Note:** Strength values (`ax_strength1/2`) are preserved as-is since they store the actual value.

### 3. WeaponSeries `augment_type` Enum

Replace `has_ax_skills` boolean with an enum that enforces mutual exclusivity:

```ruby
# Migration
remove_column :weapon_series, :has_ax_skills, :boolean
add_column :weapon_series, :augment_type, :integer, default: 0

# Data migration
WeaponSeries.where(has_ax_skills: true).update_all(augment_type: 1)
```

```ruby
# Model
enum :augment_type, { none: 0, ax: 1, befoulment: 2 }, default: :none

scope :with_ax_skills, -> { where(augment_type: :ax) }
scope :with_befoulments, -> { where(augment_type: :befoulment) }
```

---

## Seed Data

### AX Skill Modifiers (Complete List)

All AX skills from game data with their game_skill_id values:

```ruby
WeaponStatModifier.create!([
  # Primary AX Skills
  { slug: 'ax_atk', name_en: 'ATK', name_jp: '攻撃', category: 'ax', stat: 'atk', polarity: 1, suffix: '%', base_min: 1, base_max: 3.5, game_skill_id: 1589 },
  { slug: 'ax_def', name_en: 'DEF', name_jp: '防御', category: 'ax', stat: 'def', polarity: 1, suffix: '%', base_min: 1, base_max: 8, game_skill_id: 1590 },
  { slug: 'ax_hp', name_en: 'HP', name_jp: 'HP', category: 'ax', stat: 'hp', polarity: 1, suffix: '%', base_min: 1, base_max: 11, game_skill_id: 1588 },
  { slug: 'ax_ca_dmg', name_en: 'C.A. DMG', name_jp: '奥義ダメ', category: 'ax', stat: 'ca_dmg', polarity: 1, suffix: '%', base_min: 2, base_max: 8.5, game_skill_id: 1591 },
  { slug: 'ax_multiattack', name_en: 'Multiattack Rate', name_jp: '連撃率', category: 'ax', stat: 'multiattack', polarity: 1, suffix: '%', base_min: 1, base_max: 4, game_skill_id: 1592 },

  # Secondary AX Skills
  { slug: 'ax_debuff_res', name_en: 'Debuff Resistance', name_jp: '弱体耐性', category: 'ax', stat: 'debuff_res', polarity: 1, suffix: '%', base_min: 1, base_max: 3, game_skill_id: 1593 },
  { slug: 'ax_ele_atk', name_en: 'Elemental ATK', name_jp: '全属性攻撃力', category: 'ax', stat: 'ele_atk', polarity: 1, suffix: '%', base_min: 1, base_max: 5, game_skill_id: 1594 },
  { slug: 'ax_healing', name_en: 'Healing', name_jp: '回復性能', category: 'ax', stat: 'healing', polarity: 1, suffix: '%', base_min: 2, base_max: 5, game_skill_id: 1595 },
  { slug: 'ax_da', name_en: 'Double Attack Rate', name_jp: 'DA確率', category: 'ax', stat: 'da', polarity: 1, suffix: '%', base_min: 1, base_max: 2, game_skill_id: 1596 },
  { slug: 'ax_ta', name_en: 'Triple Attack Rate', name_jp: 'TA確率', category: 'ax', stat: 'ta', polarity: 1, suffix: '%', base_min: 1, base_max: 2, game_skill_id: 1597 },
  { slug: 'ax_ca_cap', name_en: 'C.A. DMG Cap', name_jp: '奥義上限', category: 'ax', stat: 'ca_cap', polarity: 1, suffix: '%', base_min: 1, base_max: 2, game_skill_id: 1599 },
  { slug: 'ax_stamina', name_en: 'Stamina', name_jp: '渾身', category: 'ax', stat: 'stamina', polarity: 1, suffix: nil, base_min: 1, base_max: 3, game_skill_id: 1600 },
  { slug: 'ax_enmity', name_en: 'Enmity', name_jp: '背水', category: 'ax', stat: 'enmity', polarity: 1, suffix: nil, base_min: 1, base_max: 3, game_skill_id: 1601 },

  # Extended AX Skills (axType 2)
  { slug: 'ax_skill_supp', name_en: 'Supplemental Skill DMG', name_jp: 'アビ与ダメ上昇', category: 'ax', stat: 'skill_supp', polarity: 1, suffix: nil, base_min: 1, base_max: 5, game_skill_id: 1719 },
  { slug: 'ax_ca_supp', name_en: 'Supplemental C.A. DMG', name_jp: '奥義与ダメ上昇', category: 'ax', stat: 'ca_supp', polarity: 1, suffix: nil, base_min: 1, base_max: 5, game_skill_id: 1720 },
  { slug: 'ax_ele_dmg_red', name_en: 'Elemental DMG Reduction', name_jp: '属性ダメ軽減', category: 'ax', stat: 'ele_dmg_red', polarity: 1, suffix: '%', base_min: 1, base_max: 5, game_skill_id: 1721 },
  { slug: 'ax_na_cap', name_en: 'Normal ATK DMG Cap', name_jp: '通常ダメ上限', category: 'ax', stat: 'na_cap', polarity: 1, suffix: '%', base_min: 0.5, base_max: 1.5, game_skill_id: 1722 },

  # Utility AX Skills (axType 3)
  { slug: 'ax_exp', name_en: 'EXP Gain', name_jp: 'EXP UP', category: 'ax', stat: 'exp', polarity: 1, suffix: '%', base_min: 5, base_max: 10, game_skill_id: 1837 },
  { slug: 'ax_rupie', name_en: 'Rupie Gain', name_jp: '獲得ルピ', category: 'ax', stat: 'rupie', polarity: 1, suffix: '%', base_min: 10, base_max: 20, game_skill_id: 1838 },
])
```

### Befoulment Modifiers

```ruby
# game_skill_id values will be populated as we discover them - we know 2880 = DEF Down
WeaponStatModifier.create!([
  { slug: 'befoul_atk_down', name_en: 'ATK Down', name_jp: '攻撃力DOWN', category: 'befoulment', stat: 'atk', polarity: -1, suffix: '%', base_min: -12, base_max: -6 },
  { slug: 'befoul_def_down', name_en: 'DEF Down', name_jp: '防御力DOWN', category: 'befoulment', stat: 'def', polarity: -1, suffix: '%', base_min: -25, base_max: -21, game_skill_id: 2880 },
  { slug: 'befoul_da_ta_down', name_en: 'DA/TA Down', name_jp: '連撃率DOWN', category: 'befoulment', stat: 'da_ta', polarity: -1, suffix: '%', base_min: -22, base_max: -19 },
  { slug: 'befoul_ca_dmg_down', name_en: 'CA DMG Down', name_jp: '奥義ダメージDOWN', category: 'befoulment', stat: 'ca_dmg', polarity: -1, suffix: '%', base_min: -38, base_max: -26 },
  { slug: 'befoul_dot', name_en: 'Damage Over Time', name_jp: '毎ターンダメージ', category: 'befoulment', stat: 'dot', polarity: -1, suffix: '%', base_min: 6, base_max: 16 },
  { slug: 'befoul_hp_down', name_en: 'Max HP Down', name_jp: '最大HP減少', category: 'befoulment', stat: 'hp', polarity: -1, suffix: '%', base_min: -50, base_max: -26 },
  { slug: 'befoul_debuff_down', name_en: 'Debuff Success Down', name_jp: '弱体成功率DOWN', category: 'befoulment', stat: 'debuff_success', polarity: -1, suffix: '%', base_min: -16, base_max: -6 },
  { slug: 'befoul_ability_dmg_down', name_en: 'Ability DMG Down', name_jp: 'アビリティダメージDOWN', category: 'befoulment', stat: 'ability_dmg', polarity: -1, suffix: '%', base_min: -50, base_max: -50 },
])
```

---

## Model Changes

### WeaponStatModifier Model

```ruby
# app/models/weapon_stat_modifier.rb
class WeaponStatModifier < ApplicationRecord
  validates :slug, presence: true, uniqueness: true
  validates :name_en, presence: true
  validates :category, presence: true, inclusion: { in: %w[ax befoulment] }
  validates :polarity, inclusion: { in: [-1, 1] }

  scope :ax_skills, -> { where(category: 'ax') }
  scope :befoulments, -> { where(category: 'befoulment') }

  def self.find_by_game_skill_id(id)
    find_by(game_skill_id: id.to_i)
  end
end
```

### CollectionWeapon Changes

```ruby
# app/models/collection_weapon.rb

# Replace old integer references with proper associations
belongs_to :ax_modifier1, class_name: 'WeaponStatModifier', optional: true
belongs_to :ax_modifier2, class_name: 'WeaponStatModifier', optional: true
belongs_to :befoulment_modifier, class_name: 'WeaponStatModifier', optional: true

validates :exorcism_level, numericality: {
  only_integer: true,
  greater_than_or_equal_to: 0,
  less_than_or_equal_to: 5
}, allow_nil: true

validate :validate_ax_skills
validate :validate_befoulment_fields

def validate_ax_skills
  # AX skill 1: must have both modifier and strength
  if (ax_modifier1.present? && ax_strength1.blank?) ||
     (ax_modifier1.blank? && ax_strength1.present?)
    errors.add(:base, "AX skill 1 must have both modifier and strength")
  end

  # AX skill 2: must have both modifier and strength
  if (ax_modifier2.present? && ax_strength2.blank?) ||
     (ax_modifier2.blank? && ax_strength2.present?)
    errors.add(:base, "AX skill 2 must have both modifier and strength")
  end

  # Validate category is 'ax'
  if ax_modifier1.present? && ax_modifier1.category != 'ax'
    errors.add(:ax_modifier1, "must be an AX skill modifier")
  end
  if ax_modifier2.present? && ax_modifier2.category != 'ax'
    errors.add(:ax_modifier2, "must be an AX skill modifier")
  end
end

def validate_befoulment_fields
  if (befoulment_modifier.present? && befoulment_strength.blank?) ||
     (befoulment_modifier.blank? && befoulment_strength.present?)
    errors.add(:base, "Befoulment must have both modifier and strength")
  end

  # Validate category is 'befoulment'
  if befoulment_modifier.present? && befoulment_modifier.category != 'befoulment'
    errors.add(:befoulment_modifier, "must be a befoulment modifier")
  end
end
```

### GridWeapon Changes

```ruby
# app/models/grid_weapon.rb

# Same associations as CollectionWeapon
belongs_to :ax_modifier1, class_name: 'WeaponStatModifier', optional: true
belongs_to :ax_modifier2, class_name: 'WeaponStatModifier', optional: true
belongs_to :befoulment_modifier, class_name: 'WeaponStatModifier', optional: true

# Same validations as CollectionWeapon
```

- Update `sync_from_collection!` to include befoulment fields
- Update `out_of_sync?` to check befoulment fields
- Update Amoeba config to nullify befoulment fields on copy

---

## API Changes

### Blueprint Serialization

```ruby
# collection_weapon_blueprint.rb

# AX skills - now with full modifier object
field :ax, if: ->(_, obj, _) { obj.ax_modifier1.present? } do |obj|
  skills = []
  if obj.ax_modifier1.present?
    skills << {
      modifier: WeaponStatModifierBlueprint.render_as_hash(obj.ax_modifier1),
      strength: obj.ax_strength1
    }
  end
  if obj.ax_modifier2.present?
    skills << {
      modifier: WeaponStatModifierBlueprint.render_as_hash(obj.ax_modifier2),
      strength: obj.ax_strength2
    }
  end
  skills
end

# Befoulment - with full modifier object
field :befoulment, if: ->(_, obj, _) { obj.befoulment_modifier.present? } do |obj|
  {
    modifier: WeaponStatModifierBlueprint.render_as_hash(obj.befoulment_modifier),
    strength: obj.befoulment_strength,
    exorcism_level: obj.exorcism_level
  }
end

# grid_weapon_blueprint.rb - similar
```

### WeaponStatModifierBlueprint

```ruby
# app/blueprints/api/v1/weapon_stat_modifier_blueprint.rb
class Api::V1::WeaponStatModifierBlueprint < Blueprinter::Base
  identifier :id
  fields :slug, :name_en, :name_jp, :category, :stat, :polarity, :suffix
end
```

### New Endpoint: GET /weapon_stat_modifiers

Return all weapon stat modifiers for frontend reference:

```ruby
# app/controllers/api/v1/weapon_stat_modifiers_controller.rb
def index
  @modifiers = WeaponStatModifier.all
  render json: WeaponStatModifierBlueprint.render(@modifiers, root: :weapon_stat_modifiers)
end
```

### Controller Params

Update `weapon_params` in both controllers:
```ruby
# Replace :ax_modifier1, :ax_modifier2 with FK versions
:ax_modifier1_id, :ax_strength1, :ax_modifier2_id, :ax_strength2,
:befoulment_modifier_id, :befoulment_strength, :exorcism_level
```

---

## Import Service

### Game JSON Structure

**Odiant weapon (with befoulment):**
```json
{
  "augment_skill_info": [[{ "skill_id": 2880, "effect_value": "25", "show_value": "-25%" }]],
  "odiant": {
    "is_odiant_weapon": true,
    "exorcision_level": 1,
    "max_exorcision_level": 5
  }
}
```

**Regular weapon (with AX skills):**
```json
{
  "augment_skill_info": [[
    { "skill_id": 1589, "effect_value": "3", "show_value": "+3%" },
    { "skill_id": 1719, "effect_value": "1_2000", "show_value": "+3" }
  ]],
  "odiant": {
    "is_odiant_weapon": false,
    "exorcision_level": 0
  }
}
```

**Key insight:** Same `augment_skill_info` structure, differentiated by `is_odiant_weapon`:
- `true` → parse as befoulment (skill_id 2880+)
- `false` → parse as AX skills (skill_id 1588-1722)

### WeaponImportService Updates

Add a cache for WeaponStatModifier lookups:

```ruby
def initialize(user, game_data, options = {})
  # ... existing code ...
  @modifier_cache = {}  # Cache for WeaponStatModifier lookups
end

def build_collection_weapon_attrs(item, weapon)
  param = item['param'] || {}

  attrs = {
    weapon: weapon,
    game_id: param['id'].to_s,
    # ... existing attrs ...
  }

  # Check if this is an Odiant (befoulment) weapon
  odiant = param['odiant']
  if odiant && odiant['is_odiant_weapon'] == true
    # Parse befoulment from augment_skill_info
    befoulment = parse_befoulment(param['augment_skill_info'])
    if befoulment
      attrs[:befoulment_modifier_id] = befoulment[:modifier_id]
      attrs[:befoulment_strength] = befoulment[:strength]
    end
    attrs[:exorcism_level] = odiant['exorcision_level'].to_i
  else
    # Regular weapon - parse AX skills
    ax_attrs = parse_ax_skills(param['augment_skill_info'])
    attrs.merge!(ax_attrs) if ax_attrs
  end

  # ... rest of existing code (awakening, etc) ...
  attrs
end

# Updated to return FK id instead of raw game_skill_id
def parse_ax_skills(augment_skill_info)
  return nil if augment_skill_info.blank? || !augment_skill_info.is_a?(Array)

  skills = augment_skill_info.first
  return nil if skills.blank? || !skills.is_a?(Array)

  attrs = {}

  # First AX skill
  if skills[0].is_a?(Hash)
    ax1 = parse_single_ax_skill(skills[0])
    if ax1
      attrs[:ax_modifier1_id] = ax1[:modifier_id]
      attrs[:ax_strength1] = ax1[:strength]
    end
  end

  # Second AX skill
  if skills[1].is_a?(Hash)
    ax2 = parse_single_ax_skill(skills[1])
    if ax2
      attrs[:ax_modifier2_id] = ax2[:modifier_id]
      attrs[:ax_strength2] = ax2[:strength]
    end
  end

  attrs.empty? ? nil : attrs
end

def parse_single_ax_skill(skill)
  return nil unless skill['skill_id'].present?

  game_skill_id = skill['skill_id'].to_i
  modifier = find_modifier_by_game_skill_id(game_skill_id)
  return nil unless modifier

  strength = parse_ax_strength(skill['effect_value'], skill['show_value'])
  return nil unless strength

  { modifier_id: modifier.id, strength: strength }
end

def parse_befoulment(augment_skill_info)
  return nil if augment_skill_info.blank? || !augment_skill_info.is_a?(Array)

  skills = augment_skill_info.first
  return nil if skills.blank? || !skills.is_a?(Array)

  skill = skills.first
  return nil unless skill.is_a?(Hash) && skill['skill_id'].present?

  game_skill_id = skill['skill_id'].to_i
  modifier = find_modifier_by_game_skill_id(game_skill_id)
  return nil unless modifier

  {
    modifier_id: modifier.id,
    strength: parse_befoulment_strength(skill['effect_value'], skill['show_value'])
  }
end

def find_modifier_by_game_skill_id(game_skill_id)
  @modifier_cache[game_skill_id] ||= WeaponStatModifier.find_by(game_skill_id: game_skill_id)
end

def parse_befoulment_strength(effect_value, show_value)
  # show_value has the sign: "-25%"
  # effect_value is unsigned: "25"
  if show_value.present?
    show_value.to_s.gsub('%', '').to_f
  elsif effect_value.present?
    -effect_value.to_f
  end
end
```

**Note:** Unknown `game_skill_id` values will be skipped (modifier not found). This is acceptable - we can add new modifiers to the seed data as we discover them.

---

## Files to Create/Modify

| File | Action |
|------|--------|
| **Migrations** | |
| `db/migrate/xxx_create_weapon_stat_modifiers.rb` | Create - new reference table |
| `db/migrate/xxx_refactor_ax_and_add_befoulments.rb` | Create - replace ax_modifier integers with FKs, add befoulment FKs |
| `db/migrate/xxx_replace_has_ax_skills_with_augment_type.rb` | Create - enum migration with data migration |
| `db/data/xxx_migrate_ax_modifiers_to_fk.rb` | Create - data migration to convert existing ax_modifier values to FK references |
| **Models** | |
| `app/models/weapon_stat_modifier.rb` | Create |
| `app/models/collection_weapon.rb` | Modify - add befoulment validation |
| `app/models/grid_weapon.rb` | Modify - add befoulment fields, sync |
| `app/models/weapon_series.rb` | Modify - replace has_ax_skills with augment_type enum |
| **Blueprints** | |
| `app/blueprints/api/v1/weapon_stat_modifier_blueprint.rb` | Create |
| `app/blueprints/api/v1/collection_weapon_blueprint.rb` | Modify - add befoulment serialization |
| `app/blueprints/api/v1/grid_weapon_blueprint.rb` | Modify - add befoulment serialization |
| `app/blueprints/api/v1/weapon_series_blueprint.rb` | Modify - replace has_ax_skills with augment_type |
| `app/blueprints/api/v1/weapon_blueprint.rb` | Modify - update series.has_ax_skills reference |
| **Controllers** | |
| `app/controllers/api/v1/weapon_stat_modifiers_controller.rb` | Create |
| `app/controllers/api/v1/collection_weapons_controller.rb` | Modify - permit befoulment params |
| `app/controllers/api/v1/grid_weapons_controller.rb` | Modify - permit befoulment params |
| `app/controllers/api/v1/weapon_series_controller.rb` | Modify - permit augment_type instead of has_ax_skills |
| **Services & Seeds** | |
| `app/services/weapon_import_service.rb` | Modify - parse befoulments |
| `db/seeds/weapon_stat_modifiers.rb` | Create |
| **Config & Tests** | |
| `config/routes.rb` | Modify - add weapon_stat_modifiers route |
| `spec/factories/weapon_series.rb` | Modify - replace has_ax_skills with augment_type |

---

## API Breaking Changes

### 1. WeaponSeries: `has_ax_skills` → `augment_type`

**Before:**
```json
{ "has_ax_skills": true }
```

**After:**
```json
{ "augment_type": "ax" }  // or "befoulment" or "none"
```

Frontend: `augment_type === 'ax'` instead of `has_ax_skills === true`.

### 2. Collection/GridWeapon: AX skill structure changed

**Before:**
```json
{
  "ax_modifier1": 1589,
  "ax_strength1": 3.0,
  "ax_modifier2": 1719,
  "ax_strength2": 2000
}
```

**After:**
```json
{
  "ax": [
    {
      "modifier": { "id": 1, "slug": "ax_atk", "name_en": "ATK Up", "category": "ax", ... },
      "strength": 3.0
    },
    {
      "modifier": { "id": 5, "slug": "ax_ability_dmg", "name_en": "Ability DMG Up", "category": "ax", ... },
      "strength": 2000
    }
  ]
}
```

Frontend: Access via `weapon.ax[0].modifier.slug` instead of `weapon.ax_modifier1`.

---

## Implementation Considerations

### Migration Order

Migrations must be deployed in this order:

1. `create_weapon_stat_modifiers` - Create table + seed data
2. `add_ax_and_befoulment_fk_columns` - Add new FK columns (keep old integer columns)
3. `migrate_ax_modifiers_to_fk` - Data migration: lookup existing values → FK refs
4. `remove_old_ax_modifier_columns` - Remove old integer columns
5. `replace_has_ax_skills_with_augment_type` - WeaponSeries enum change

### GridWeapon Amoeba Config

Update nullify list for party cloning:

```ruby
amoeba do
  nullify :ax_modifier1_id
  nullify :ax_modifier2_id
  nullify :ax_strength1
  nullify :ax_strength2
  nullify :befoulment_modifier_id
  nullify :befoulment_strength
  nullify :exorcism_level
end
```

### Unknown Skill ID Logging

When import encounters unknown `game_skill_id`, log with icon image for discovery:

```ruby
Rails.logger.warn(
  "[WeaponImportService] Unknown augment skill_id=#{game_skill_id} " \
  "icon=#{skill['augment_skill_icon_image']}"
)
```

### Database Indexes

Add index on `weapon_stat_modifiers.game_skill_id` for fast import lookups:

```ruby
add_index :weapon_stat_modifiers, :game_skill_id, unique: true
```

### Coordinated Release

Frontend and backend releases will be coordinated. No backwards compatibility layer needed.

---

## Next Steps

1. ✅ **Game JSON samples** - received for both Odiant and regular weapons
2. **Identify Odiant weapon series** in database (set `augment_type: :befoulment`)
3. **Discover remaining game_skill_ids** for other befoulment types (we know 2880 = DEF Down)
4. **Verify AX skill IDs** match between AX_MAPPING and game data

## Known Skill IDs

### AX Skills (Complete)

| skill_id | Stat | Name (EN) | Name (JP) | Suffix |
|----------|------|-----------|-----------|--------|
| 1588 | hp | HP | HP | % |
| 1589 | atk | ATK | 攻撃 | % |
| 1590 | def | DEF | 防御 | % |
| 1591 | ca_dmg | C.A. DMG | 奥義ダメ | % |
| 1592 | multiattack | Multiattack Rate | 連撃率 | % |
| 1593 | debuff_res | Debuff Resistance | 弱体耐性 | % |
| 1594 | ele_atk | Elemental ATK | 全属性攻撃力 | % |
| 1595 | healing | Healing | 回復性能 | % |
| 1596 | da | Double Attack Rate | DA確率 | % |
| 1597 | ta | Triple Attack Rate | TA確率 | % |
| 1599 | ca_cap | C.A. DMG Cap | 奥義上限 | % |
| 1600 | stamina | Stamina | 渾身 | - |
| 1601 | enmity | Enmity | 背水 | - |
| 1719 | skill_supp | Supplemental Skill DMG | アビ与ダメ上昇 | - |
| 1720 | ca_supp | Supplemental C.A. DMG | 奥義与ダメ上昇 | - |
| 1721 | ele_dmg_red | Elemental DMG Reduction | 属性ダメ軽減 | % |
| 1722 | na_cap | Normal ATK DMG Cap | 通常ダメ上限 | % |
| 1837 | exp | EXP Gain | EXP UP | % |
| 1838 | rupie | Rupie Gain | 獲得ルピ | % |

### Befoulments (Partial - more to discover)

| skill_id | Stat | Name (EN) | Name (JP) |
|----------|------|-----------|-----------|
| 2880 | def | DEF Down | 防御力DOWN |
| ? | atk | ATK Down | 攻撃力DOWN |
| ? | da_ta | DA/TA Down | 連撃率DOWN |
| ? | ca_dmg | CA DMG Down | 奥義ダメージDOWN |
| ? | dot | Damage Over Time | 毎ターンダメージ |
| ? | hp | Max HP Down | 最大HP減少 |
| ? | debuff_success | Debuff Success Down | 弱体成功率DOWN |
| ? | ability_dmg | Ability DMG Down | アビリティダメージDOWN |

(Befoulment skill_ids will be discovered as users import Odiant weapons)
