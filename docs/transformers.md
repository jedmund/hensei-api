# Data Transformers Documentation

The transformer system converts game data between different formats and structures. It handles element mapping, data normalization, and format conversions for characters, weapons, and summons.

## Architecture

### Base Transformer

All transformers inherit from `BaseTransformer` which provides:
- Data validation
- Element mapping (game ↔ internal)
- Error handling with detailed context
- Debug logging
- Common transformation utilities

### Element Mapping

The system uses different element IDs internally vs the game:

```ruby
ELEMENT_MAPPING = {
  0 => nil,  # Null/None
  1 => 4,    # Wind → Earth
  2 => 2,    # Fire → Fire
  3 => 3,    # Water → Water
  4 => 1,    # Earth → Wind
  5 => 6,    # Dark → Light
  6 => 5     # Light → Dark
}
```

### Available Transformers

#### CharacterTransformer
Transforms character data for different contexts.

**Transformations:**
- Game format → Database format
- Database format → API response
- Wiki data → Database format
- Legacy format → Current format

**Usage:**
```ruby
# Transform game data to database format
game_data = {
  id: "3040001000",
  name: "Katalina",
  element: 3,  # Water in game format
  hp: 1680,
  atk: 7200
}

transformer = Granblue::Transformers::CharacterTransformer.new(game_data)
db_data = transformer.transform
# => { granblue_id: "3040001000", name_en: "Katalina", element: 3, ... }

# Transform for API response
transformer = Granblue::Transformers::CharacterTransformer.new(
  character,
  format: :api
)
api_data = transformer.transform
```

#### WeaponTransformer
Transforms weapon data between formats.

**Transformations:**
- Skill format conversions
- Awakening data mapping
- Element transformations
- Legacy skill migrations

**Usage:**
```ruby
weapon_data = {
  id: "1040001000",
  name: "Murgleis",
  element: 3,
  skills: [{ name: "Hoarfrost's Might", level: 10 }]
}

transformer = Granblue::Transformers::WeaponTransformer.new(weapon_data)
transformed = transformer.transform
```

#### SummonTransformer
Transforms summon data between formats.

**Transformations:**
- Call effect formatting
- Aura data structuring
- Sub-aura conversions
- Cooldown normalization

**Usage:**
```ruby
summon_data = {
  id: "2040001000",
  name: "Bahamut",
  element: 0,
  call_effect: "120% Dark damage",
  initial_cd: 9,
  recast: 10
}

transformer = Granblue::Transformers::SummonTransformer.new(summon_data)
transformed = transformer.transform
```

#### BaseDeckTransformer
Transforms party/deck configurations.

**Transformations:**
- Party format → Deck format
- Grid positions mapping
- Equipment slot conversions
- Skill selection formatting

**Usage:**
```ruby
party_data = {
  characters: [char1, char2, char3],
  weapons: [weapon1, weapon2, ...],
  summons: [summon1, summon2, ...]
}

transformer = Granblue::Transformers::BaseDeckTransformer.new(party_data)
deck = transformer.transform
```

## Transformation Patterns

### Input Validation

```ruby
class CustomTransformer < BaseTransformer
  def transform
    validate_data

    # Transformation logic
    {
      id: @data[:id],
      name: transform_name(@data[:name]),
      element: transform_element(@data[:element])
    }
  end

  private

  def validate_data
    raise TransformerError.new("Missing ID") if @data[:id].blank?
    raise TransformerError.new("Invalid element") unless valid_element?
  end

  def valid_element?
    (0..6).include?(@data[:element].to_i)
  end
end
```

### Element Transformation

```ruby
# Game to internal
def transform_element_to_internal(game_element)
  ELEMENT_MAPPING[game_element] || 0
end

# Internal to game
def transform_element_to_game(internal_element)
  ELEMENT_MAPPING.invert[internal_element] || 0
end

# Element name
def element_name(element_id)
  %w[Null Wind Fire Water Earth Dark Light][element_id]
end
```

### Safe Value Extraction

```ruby
def safe_integer(value, default = 0)
  Integer(value.to_s)
rescue ArgumentError, TypeError
  default
end

def safe_string(value, default = "")
  value.to_s.presence || default
end

def safe_boolean(value, default = false)
  return default if value.nil?
  ActiveModel::Type::Boolean.new.cast(value)
end
```

### Nested Data Transformation

```ruby
def transform_skills(skills)
  return [] if skills.blank?

  skills.map do |skill|
    {
      name: safe_string(skill[:name]),
      description: safe_string(skill[:description]),
      cooldown: safe_integer(skill[:cd]),
      effects: transform_skill_effects(skill[:effects])
    }
  end
end

def transform_skill_effects(effects)
  return [] if effects.blank?

  effects.map do |effect|
    {
      type: effect[:type].to_s.underscore,
      value: safe_integer(effect[:value]),
      target: effect[:target] || "self"
    }
  end
end
```

## Error Handling

### TransformerError

Custom error class with context:

```ruby
class TransformerError < StandardError
  attr_reader :details

  def initialize(message, details = nil)
    @details = details
    super(message)
  end
end

# Usage
raise TransformerError.new(
  "Invalid skill format",
  { skill: skill_data, index: index }
)
```

### Error Recovery

```ruby
def transform_with_fallback
  begin
    primary_transform
  rescue TransformerError => e
    Rails.logger.warn "Transform failed: #{e.message}"
    fallback_transform
  end
end
```

### Validation Errors

```ruby
def validate_and_transform
  errors = []

  errors << "Missing name" if @data[:name].blank?
  errors << "Invalid HP" if @data[:hp].to_i <= 0
  errors << "Invalid element" unless valid_element?

  if errors.any?
    raise TransformerError.new(
      "Validation failed",
      { errors: errors, data: @data }
    )
  end

  perform_transform
end
```

## Format Specifications

### API Format

```ruby
class ApiTransformer < BaseTransformer
  def transform
    {
      id: @data.granblue_id,
      name: {
        en: @data.name_en,
        jp: @data.name_jp
      },
      element: element_name(@data.element),
      rarity: rarity_string(@data.rarity),
      stats: {
        hp: @data.hp,
        atk: @data.atk
      },
      skills: transform_skills(@data.skills)
    }
  end
end
```

### Database Format

```ruby
class DatabaseTransformer < BaseTransformer
  def transform
    {
      granblue_id: @data[:id].to_s,
      name_en: @data[:name][:en],
      name_jp: @data[:name][:jp],
      element: parse_element(@data[:element]),
      rarity: parse_rarity(@data[:rarity]),
      hp: @data[:stats][:hp].to_i,
      atk: @data[:stats][:atk].to_i
    }
  end
end
```

### Legacy Format Migration

```ruby
class LegacyTransformer < BaseTransformer
  def transform
    # Map old field names to new
    {
      granblue_id: @data[:char_id] || @data[:id],
      name_en: @data[:name_english] || @data[:name],
      element: map_legacy_element(@data[:elem]),
      # Handle removed fields
      deprecated_field: nil
    }
  end

  private

  def map_legacy_element(elem)
    # Old system used different IDs
    legacy_mapping = {
      "wind" => 1,
      "fire" => 2,
      "water" => 3,
      "earth" => 4
    }
    legacy_mapping[elem.to_s.downcase] || 0
  end
end
```

## Best Practices

### 1. Always Validate Input
```ruby
def transform
  validate_required_fields
  validate_data_types
  validate_ranges

  perform_transform
end
```

### 2. Use Safe Extraction Methods
```ruby
# Good
name = safe_string(@data[:name], "Unknown")

# Bad
name = @data[:name] # Could be nil
```

### 3. Provide Clear Error Messages
```ruby
raise TransformerError.new(
  "Element value '#{element}' is not valid. Expected 0-6.",
  { element: element, valid_range: (0..6) }
)
```

### 4. Log Transformations
```ruby
def transform
  Rails.logger.info "[TRANSFORM] Starting #{self.class.name}"
  result = perform_transform
  Rails.logger.info "[TRANSFORM] Completed with #{result.keys.count} fields"
  result
rescue => e
  Rails.logger.error "[TRANSFORM] Failed: #{e.message}"
  raise
end
```

### 5. Handle Missing Data Gracefully
```ruby
def transform_optional_field(value)
  return nil if value.blank?

  # Transform only if present
  value.to_s.upcase
end
```

## Custom Transformer Implementation

```ruby
module Granblue
  module Transformers
    class CustomTransformer < BaseTransformer
      # Define transformation options
      OPTIONS = {
        format: :database,
        include_metadata: false,
        validate_strict: true
      }.freeze

      def initialize(data, options = {})
        super(data, OPTIONS.merge(options))
      end

      def transform
        validate_data if @options[:validate_strict]

        base_transform.tap do |result|
          result[:metadata] = metadata if @options[:include_metadata]
        end
      end

      private

      def base_transform
        {
          id: @data[:id],
          type: determine_type,
          attributes: transform_attributes,
          relationships: transform_relationships
        }
      end

      def transform_attributes
        {
          name: safe_string(@data[:name]),
          description: safe_string(@data[:desc]),
          stats: transform_stats
        }
      end

      def transform_stats
        return {} unless @data[:stats]

        @data[:stats].transform_values { |v| safe_integer(v) }
      end

      def transform_relationships
        {
          parent_id: @data[:parent],
          child_ids: Array(@data[:children])
        }
      end

      def metadata
        {
          transformed_at: Time.current,
          transformer: self.class.name,
          version: "1.0"
        }
      end
    end
  end
end
```

## Testing Transformers

### Unit Tests

```ruby
RSpec.describe Granblue::Transformers::CharacterTransformer do
  let(:input_data) do
    {
      id: "3040001000",
      name: "Test Character",
      element: 3,
      hp: 1000,
      atk: 500
    }
  end

  subject { described_class.new(input_data) }

  describe "#transform" do
    it "transforms game data to database format" do
      result = subject.transform

      expect(result[:granblue_id]).to eq("3040001000")
      expect(result[:name_en]).to eq("Test Character")
      expect(result[:element]).to eq(3)
    end

    it "handles missing optional fields" do
      input_data.delete(:hp)

      expect { subject.transform }.not_to raise_error
    end

    it "raises error for invalid element" do
      input_data[:element] = 99

      expect { subject.transform }.to raise_error(TransformerError)
    end
  end
end
```

### Integration Tests

```ruby
# Test full pipeline
character_data = fetch_from_api
transformer = CharacterTransformer.new(character_data)
transformed = transformer.transform
character = Character.create!(transformed)

expect(character.persisted?).to be true
expect(character.element).to eq(transformed[:element])
```

## Troubleshooting

### Transformation Returns Nil
1. Check input data is not nil
2. Verify required fields are present
3. Enable debug logging
4. Check for silent rescue blocks

### Wrong Element Mapping
1. Verify using correct mapping direction
2. Check for element ID vs name confusion
3. Ensure consistent element system

### Data Loss During Transform
1. Check all fields are mapped
2. Verify no fields silently dropped
3. Add logging for each field
4. Compare input and output keys

### Performance Issues
1. Cache repeated transformations
2. Use batch transformations
3. Avoid N+1 queries in transformers
4. Profile transformation methods