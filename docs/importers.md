# Data Importers Documentation

The importer system provides a framework for importing game data from CSV files into the database. It supports test mode for validation, tracks new and updated records, and provides detailed error reporting.

## Architecture

### Base Importer

All importers inherit from `BaseImporter` which provides:
- CSV parsing and validation
- Test mode for dry runs
- New and updated record tracking
- Error handling and reporting
- Verbose logging support
- Batch processing with ActiveRecord transactions

### Available Importers

#### CharacterImporter
Imports character data from CSV files.

**Required CSV Fields:**
- `granblue_id` - Unique character ID
- `name_en` - English name
- `name_jp` - Japanese name
- `rarity` - Character rarity
- `element` - Element type
- `flb` - Has 5★ uncap (true/false)
- `ulb` - Has 6★ uncap (true/false)
- `wiki_en` - Wiki page name

**Example CSV:**
```csv
granblue_id,name_en,name_jp,rarity,element,flb,ulb,wiki_en
3040001000,Katalina,カタリナ,4,3,true,false,Katalina
```

#### WeaponImporter
Imports weapon data from CSV files.

**Required CSV Fields:**
- `granblue_id` - Unique weapon ID
- `name_en` - English name
- `name_jp` - Japanese name
- `rarity` - Weapon rarity
- `element` - Element type
- `weapon_type` - Type of weapon
- `wiki_en` - Wiki page name

**Example CSV:**
```csv
granblue_id,name_en,name_jp,rarity,element,weapon_type,wiki_en
1040001000,Murgleis,ミュルグレス,5,3,1,Murgleis
```

#### SummonImporter
Imports summon data from CSV files.

**Required CSV Fields:**
- `granblue_id` - Unique summon ID
- `name_en` - English name
- `name_jp` - Japanese name
- `rarity` - Summon rarity
- `element` - Element type
- `max_level` - Maximum level
- `wiki_en` - Wiki page name

**Example CSV:**
```csv
granblue_id,name_en,name_jp,rarity,element,max_level,wiki_en
2040001000,Bahamut,バハムート,5,0,150,Bahamut
```

## Usage

### Ruby API

```ruby
# Import character data
importer = Granblue::Importers::CharacterImporter.new(
  'db/seed/updates/characters.csv',
  test_mode: false,
  verbose: true
)
result = importer.import

# Check results
result[:new_records]     # => Array of newly created records
result[:updated_records] # => Array of updated records
result[:errors]          # => Array of error messages

# Test mode - validate without importing
test_importer = Granblue::Importers::WeaponImporter.new(
  'db/seed/updates/weapons.csv',
  test_mode: true,
  verbose: true
)
test_result = test_importer.import
```

### Rake Task

The main import task processes all CSV files in `db/seed/updates/`:

```bash
# Import all CSV files
rake granblue:import_data

# Test mode - validate without importing
rake granblue:import_data TEST=true

# Verbose output
rake granblue:import_data VERBOSE=true

# Both test and verbose
rake granblue:import_data TEST=true VERBOSE=true
```

## CSV File Format

### File Location
Place CSV files in: `db/seed/updates/`

### Naming Convention
- `characters_YYYYMMDD.csv` - Character data
- `weapons_YYYYMMDD.csv` - Weapon data
- `summons_YYYYMMDD.csv` - Summon data

### Encoding
- UTF-8 encoding required
- Unix line endings (LF) preferred

### Headers
- First row must contain field names
- Field names are case-sensitive
- Order doesn't matter

### Data Types
- **Strings**: Plain text, quotes optional unless contains commas
- **Numbers**: Integer or decimal values
- **Booleans**: `true` or `false` (lowercase)
- **Dates**: ISO 8601 format (YYYY-MM-DD)
- **Empty values**: Leave blank or use empty string

## Field Mappings

### Element Values
```
0 = Null/None
1 = Wind
2 = Fire
3 = Water
4 = Earth
5 = Dark
6 = Light
```

### Weapon Types
```
1 = Sword
2 = Dagger
3 = Spear
4 = Axe
5 = Staff
6 = Gun
7 = Melee
8 = Bow
9 = Harp
10 = Katana
```

### Rarity Values
```
1 = R (Rare)
2 = SR (Super Rare)
3 = SSR (Super Super Rare)
4 = SSR+
5 = Grand/Limited
```

## Test Mode

Test mode validates data without making database changes:

```bash
rake granblue:import_data TEST=true
```

Test mode will:
1. Parse CSV files
2. Validate all data
3. Check for duplicates
4. Report what would be created/updated
5. Show any validation errors
6. **NOT** save to database

Output example:
```
[TEST MODE] Would create Character: Katalina (3040001000)
[TEST MODE] Would update Weapon: Murgleis (1040001000)
[TEST MODE] Validation error for Summon: Invalid element value
```

## Error Handling

### Import Errors

The importer tracks various error types:

```ruby
{
  errors: [
    {
      row: 5,
      field: 'element',
      message: 'Invalid element value: 99',
      record: { granblue_id: '3040001000', name_en: 'Katalina' }
    }
  ]
}
```

### Validation Errors

Records are validated before save:
- Required fields must be present
- Granblue ID must be unique
- Element must be valid (0-6)
- Rarity must be valid (1-5)

### Duplicate Handling

When a record with the same `granblue_id` exists:
1. Existing record is updated with new values
2. Update is tracked in `updated_records`
3. Original values are preserved in update log

## Batch Processing

The import system uses transactions for efficiency:

```ruby
ActiveRecord::Base.transaction do
  records.each do |record|
    # Process record
  end
end
```

Benefits:
- All-or-nothing imports
- Better performance
- Automatic rollback on errors

## Best Practices

### 1. Always Test First
```bash
# Test mode first
rake granblue:import_data TEST=true VERBOSE=true

# Review output, then import
rake granblue:import_data VERBOSE=true
```

### 2. Use Dated Filenames
```
db/seed/updates/
├── characters_20240101.csv
├── weapons_20240115.csv
└── summons_20240201.csv
```

### 3. Validate Data Format
Before importing:
- Check CSV encoding (UTF-8)
- Verify headers match expected fields
- Validate element and rarity values
- Ensure granblue_id uniqueness

### 4. Backup Before Large Imports
```bash
# Backup database
pg_dump hensei_development > backup_$(date +%Y%m%d).sql

# Run import
rake granblue:import_data

# If issues, restore
psql hensei_development < backup_20240315.sql
```

### 5. Monitor Import Results
```ruby
# In Rails console
import_log = ImportLog.last
import_log.new_records_count
import_log.updated_records_count
import_log.errors
```

## Custom Importer Implementation

To create a custom importer:

```ruby
module Granblue
  module Importers
    class CustomImporter < BaseImporter
      private

      # Required: specify model class
      def model_class
        CustomModel
      end

      # Required: build attributes from CSV row
      def build_attributes(row)
        {
          granblue_id: parse_value(row['granblue_id']),
          name_en: parse_value(row['name_en']),
          name_jp: parse_value(row['name_jp']),
          custom_field: parse_custom_value(row['custom'])
        }
      end

      # Optional: custom parsing logic
      def parse_custom_value(value)
        # Custom parsing
        value.to_s.upcase
      end

      # Optional: additional validation
      def validate_record(attributes)
        errors = []
        if attributes[:custom_field].blank?
          errors << "Custom field is required"
        end
        errors
      end
    end
  end
end
```

## Data Pipeline

Complete data import pipeline:

1. **Export from source** → CSV files
2. **Place in updates folder** → `db/seed/updates/`
3. **Test import** → `rake granblue:import_data TEST=true`
4. **Review results** → Check logs for errors
5. **Execute import** → `rake granblue:import_data`
6. **Download images** → `rake granblue:download_all_images[type]`
7. **Fetch wiki data** → `rake granblue:fetch_wiki_data`

## Troubleshooting

### Import Not Finding Files
1. Check files are in `db/seed/updates/`
2. Verify file extensions are `.csv`
3. Ensure file permissions allow reading

### Validation Errors
1. Check CSV headers match expected fields
2. Verify data types (strings, numbers, booleans)
3. Validate element and rarity values
4. Ensure granblue_id is unique

### Encoding Issues
1. Save CSV as UTF-8
2. Remove BOM if present
3. Use Unix line endings (LF)
4. Check for special characters

### Performance Issues
For large imports:
1. Use batch processing
2. Disable callbacks if safe
3. Consider direct SQL for bulk operations
4. Import in smaller chunks

### Debugging
Enable verbose mode:
```bash
rake granblue:import_data VERBOSE=true
```

Check Rails console:
```ruby
# Recent imports
ImportLog.recent

# Failed imports
ImportLog.where(status: 'failed')

# Check specific record
Character.find_by(granblue_id: '3040001000')
```