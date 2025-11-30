# Wiki Parsers Documentation

The parser system extracts and processes data from the Granblue Fantasy Wiki. It fetches wiki pages, parses wikitext format, and extracts structured data for characters, weapons, and summons.

## Architecture

### Base Parser

All parsers inherit from `BaseParser` which provides:
- Wiki page fetching via MediaWiki API
- Redirect handling
- Wikitext parsing
- Template extraction
- Error handling and debugging
- Local cache support

### Wiki Client

The `Wiki` class handles API communication:
- MediaWiki API integration
- Page content fetching
- Redirect detection
- Rate limiting
- Error handling

### Available Parsers

#### CharacterParser
Extracts character data from wiki pages.

**Extracted Data:**
- Character stats (HP, ATK)
- Skills and abilities
- Charge attack details
- Voice actor information
- Release dates
- Character metadata

**Usage:**
```ruby
character = Character.find_by(granblue_id: "3040001000")
parser = Granblue::Parsers::CharacterParser.new(character)

# Fetch and parse wiki data
data = parser.fetch(save: false)

# Fetch, parse, and save to database
parser.fetch(save: true)

# Use local cached wiki data
parser = Granblue::Parsers::CharacterParser.new(character, use_local: true)
data = parser.fetch
```

#### WeaponParser
Extracts weapon data from wiki pages.

**Extracted Data:**
- Weapon stats (HP, ATK)
- Weapon skills
- Ougi (charge attack) effects
- Crafting requirements
- Upgrade materials

**Usage:**
```ruby
weapon = Weapon.find_by(granblue_id: "1040001000")
parser = Granblue::Parsers::WeaponParser.new(weapon)
data = parser.fetch(save: true)
```

#### SummonParser
Extracts summon data from wiki pages.

**Extracted Data:**
- Summon stats (HP, ATK)
- Call effects
- Aura effects
- Cooldown information
- Sub-aura details

**Usage:**
```ruby
summon = Summon.find_by(granblue_id: "2040001000")
parser = Granblue::Parsers::SummonParser.new(summon)
data = parser.fetch(save: true)
```

#### CharacterSkillParser
Parses individual character skills.

**Extracted Data:**
- Skill name and description
- Cooldown and duration
- Effect values by level
- Skill upgrade requirements

**Usage:**
```ruby
parser = Granblue::Parsers::CharacterSkillParser.new(skill_text)
skill_data = parser.parse
```

#### WeaponSkillParser
Parses weapon skill information.

**Extracted Data:**
- Skill name and type
- Effect percentages
- Skill level scaling
- Awakening effects

**Usage:**
```ruby
parser = Granblue::Parsers::WeaponSkillParser.new(skill_text)
skill_data = parser.parse
```

## Rake Tasks

### Fetch Wiki Data

```bash
# Fetch all characters
rake granblue:fetch_wiki_data

# Fetch specific type
rake granblue:fetch_wiki_data type=Weapon
rake granblue:fetch_wiki_data type=Summon

# Fetch specific item
rake granblue:fetch_wiki_data type=Character id=3040001000

# Force re-fetch even if data exists
rake granblue:fetch_wiki_data force=true
```

### Parameters

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `type` | Character, Weapon, Summon | Character | Type of object to fetch |
| `id` | Granblue ID | all | Specific item or all |
| `force` | true/false | false | Re-fetch even if wiki_raw exists |

## Wiki Data Storage

### Database Fields

Each model has wiki-related fields:
- `wiki_en` - English wiki page name
- `wiki_jp` - Japanese wiki page name (if available)
- `wiki_raw` - Raw wikitext cache
- `wiki_updated_at` - Last fetch timestamp

### Caching Strategy

1. **Initial Fetch**: Wiki data fetched from API
2. **Raw Storage**: Wikitext stored in `wiki_raw`
3. **Local Parsing**: Parsers use cached data when available
4. **Refresh**: Force flag bypasses cache

## Wikitext Format

### Templates
Wiki pages use templates for structured data:
```
{{Character
|id=3040001000
|name=Katalina
|element=Water
|rarity=SSR
|hp=1680
|atk=7200
}}
```

### Tables
Stats and skills in table format:
```
{| class="wikitable"
! Level !! HP !! ATK
|-
| 1 || 280 || 1200
|-
| 100 || 1680 || 7200
|}
```

### Skills
Skill descriptions with effects:
```
|skill1_name = Blade of Light
|skill1_desc = 400% Water damage to one enemy
|skill1_cd = 7 turns
```

## Parser Implementation

### Basic Parser Structure

```ruby
module Granblue
  module Parsers
    class CustomParser < BaseParser
      def parse_content(wikitext)
        data = {}

        # Extract template data
        template = extract_template(wikitext)
        data[:name] = template['name']
        data[:element] = parse_element(template['element'])

        # Parse tables
        tables = extract_tables(wikitext)
        data[:stats] = parse_stat_table(tables.first)

        # Parse skills
        data[:skills] = parse_skills(wikitext)

        data
      end

      private

      def parse_element(element_text)
        case element_text.downcase
        when 'fire' then 2
        when 'water' then 3
        when 'earth' then 4
        when 'wind' then 1
        when 'light' then 6
        when 'dark' then 5
        else 0
        end
      end
    end
  end
end
```

### Template Extraction

```ruby
def extract_template(wikitext)
  template_match = wikitext.match(/\{\{(\w+)(.*?)\}\}/m)
  return {} unless template_match

  template_name = template_match[1]
  template_content = template_match[2]

  params = {}
  template_content.scan(/\|(\w+)\s*=\s*([^\|]*)/) do |key, value|
    params[key] = value.strip
  end

  params
end
```

### Table Parsing

```ruby
def extract_tables(wikitext)
  tables = []
  wikitext.scan(/\{\|.*?\|\}/m) do |table|
    rows = []
    table.scan(/\|-\s*(.*?)(?=\|-|\|\})/m) do |row|
      cells = row[0].split('||').map(&:strip)
      rows << cells unless cells.empty?
    end
    tables << rows
  end
  tables
end
```

## Error Handling

### Redirect Handling
When a page redirects:
```ruby
# Automatic redirect detection
redirect_match = wikitext.match(/#REDIRECT \[\[(.*?)\]\]/)
if redirect_match
  # Update wiki_en to new page
  object.update!(wiki_en: redirect_match[1])
  # Fetch new page
  fetch_wiki_info(redirect_match[1])
end
```

### API Errors
Common errors and handling:
```ruby
begin
  response = wiki_client.fetch(page_name)
rescue Net::ReadTimeout
  Rails.logger.error "Wiki API timeout for #{page_name}"
  return nil
rescue JSON::ParserError => e
  Rails.logger.error "Invalid wiki response: #{e.message}"
  return nil
end
```

### Parse Errors
Safe parsing with defaults:
```ruby
def safe_parse_integer(value, default = 0)
  Integer(value.to_s.gsub(/[^\d]/, ''))
rescue ArgumentError
  default
end
```

## Best Practices

### 1. Cache Wiki Data
```bash
# Fetch and cache all wiki data first
rake granblue:fetch_wiki_data type=Character
rake granblue:fetch_wiki_data type=Weapon
rake granblue:fetch_wiki_data type=Summon

# Then parse using cached data
parser = CharacterParser.new(character, use_local: true)
```

### 2. Handle Missing Pages
```ruby
if object.wiki_en.blank?
  Rails.logger.warn "No wiki page for #{object.name_en}"
  return nil
end
```

### 3. Validate Parsed Data
```ruby
data = parser.fetch
if data[:hp].nil? || data[:atk].nil?
  Rails.logger.error "Missing required stats for #{object.name_en}"
end
```

### 4. Rate Limiting
```ruby
# Add delays between requests
objects.each do |object|
  parser = CharacterParser.new(object)
  parser.fetch
  sleep(1) # Respect wiki rate limits
end
```

### 5. Error Recovery
```ruby
begin
  data = parser.fetch(save: true)
rescue => e
  Rails.logger.error "Parse failed: #{e.message}"
  # Try with cached data
  parser = CharacterParser.new(object, use_local: true)
  data = parser.fetch
end
```

## Debugging

### Enable Debug Mode
```ruby
parser = Granblue::Parsers::CharacterParser.new(
  character,
  debug: true
)
data = parser.fetch
```

Debug output shows:
- API requests made
- Template data extracted
- Parsing steps
- Data transformations

### Inspect Raw Wiki Data
```ruby
# In Rails console
character = Character.find_by(granblue_id: "3040001000")
puts character.wiki_raw

# Check for specific content
character.wiki_raw.include?("charge_attack")
```

### Test Parsing
```ruby
# Test with sample wikitext
sample = "{{Character|name=Test|hp=1000}}"
parser = CharacterParser.new(character)
data = parser.parse_content(sample)
```

## Advanced Usage

### Custom Field Extraction
```ruby
class CustomParser < BaseParser
  def parse_custom_field(wikitext)
    # Extract custom pattern
    if match = wikitext.match(/custom_pattern:\s*(.+)/)
      match[1].strip
    end
  end
end
```

### Batch Processing
```ruby
# Process in batches to avoid memory issues
Character.find_in_batches(batch_size: 100) do |batch|
  batch.each do |character|
    next if character.wiki_raw.present?

    parser = CharacterParser.new(character)
    parser.fetch(save: true)
    sleep(1)
  end
end
```

### Parallel Processing
```ruby
require 'parallel'

characters = Character.where(wiki_raw: nil)
Parallel.each(characters, in_threads: 4) do |character|
  ActiveRecord::Base.connection_pool.with_connection do
    parser = CharacterParser.new(character)
    parser.fetch(save: true)
  end
end
```

## Troubleshooting

### Wiki Page Not Found
1. Verify wiki_en field has correct page name
2. Check for redirects on wiki
3. Try searching wiki manually
4. Update wiki_en if page moved

### Parsing Returns Empty Data
1. Check wiki_raw has content
2. Verify template format hasn't changed
3. Enable debug mode to see parsing steps
4. Check for wiki page format changes

### API Timeouts
1. Increase timeout in Wiki client
2. Add retry logic
3. Use cached data when available
4. Process in smaller batches

### Data Inconsistencies
1. Force re-fetch with `force=true`
2. Clear wiki_raw and re-fetch
3. Check wiki edit history for changes
4. Compare with other items of same type