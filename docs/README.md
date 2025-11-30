# Hensei API Utilities Documentation

This directory contains documentation for the various utilities and tools available in the hensei-api `/lib` folder. These utilities handle data import/export, image downloading, wiki parsing, and data transformation for Granblue Fantasy game assets.

## Quick Start

The most common tasks you'll perform:

```bash
# Download images for a specific character
rake granblue:export:character_images[3040001000]

# Import data from CSV files
rake granblue:import_data

# Fetch wiki data for all characters
rake granblue:fetch_wiki_data type=Character

# Generate party preview images
rake previews:generate_all
```

## Documentation Structure

### Core Utilities

- **[Downloaders](./downloaders.md)** - Image downloading system for game assets
  - Character, Weapon, Summon, and Job image downloaders
  - Support for multiple image sizes and variants
  - S3 and local storage options

- **[Importers](./importers.md)** - CSV data import system
  - Bulk import of character, weapon, and summon data
  - Test mode for validation
  - Update tracking and error handling

- **[Parsers](./parsers.md)** - Wiki data extraction and parsing
  - Fetch and parse data from Granblue Fantasy Wiki
  - Character, weapon, and summon information extraction
  - Skill parsing and data normalization

- **[Transformers](./transformers.md)** - Data transformation utilities
  - Convert between different data formats
  - Element mapping and normalization
  - Error handling and validation

### Task Reference

- **[Rake Tasks](./rake-tasks.md)** - Complete guide to all available rake tasks
  - Data management tasks
  - Image download tasks
  - Wiki synchronization
  - Preview generation
  - Database utilities

## Architecture Overview

```
lib/
├── granblue/
│   ├── downloaders/        # Image download utilities
│   │   ├── base_downloader.rb
│   │   ├── character_downloader.rb
│   │   ├── weapon_downloader.rb
│   │   ├── summon_downloader.rb
│   │   └── job_downloader.rb
│   │
│   ├── importers/           # CSV import utilities
│   │   ├── base_importer.rb
│   │   ├── character_importer.rb
│   │   ├── weapon_importer.rb
│   │   └── summon_importer.rb
│   │
│   ├── parsers/             # Wiki parsing utilities
│   │   ├── base_parser.rb
│   │   ├── character_parser.rb
│   │   ├── weapon_parser.rb
│   │   └── summon_parser.rb
│   │
│   └── transformers/        # Data transformation
│       ├── base_transformer.rb
│       ├── character_transformer.rb
│       ├── weapon_transformer.rb
│       └── summon_transformer.rb
│
└── tasks/                   # Rake tasks
    ├── download_all_images.rake
    ├── export_*.rake
    ├── fetch_wiki.rake
    ├── import_data.rake
    └── previews.rake
```

## Common Workflows

### Adding New Game Content

1. **Fetch wiki data** for the new content:
   ```bash
   rake granblue:fetch_wiki_data type=Character id=3040001000
   ```

2. **Import CSV data** if available:
   ```bash
   # Place CSV in db/seed/updates/
   rake granblue:import_data
   ```

3. **Download images** for the content:
   ```bash
   rake granblue:export:character_images[3040001000]
   ```

### Bulk Operations

For processing multiple items:

```bash
# Download all character images with parallel processing
rake granblue:download_all_images[character,4]

# Download only specific image sizes
rake granblue:download_all_images[weapon,4,grid]

# Test mode - simulate without actual downloads
rake granblue:export:weapon_images[,true,true,both]
```

### Storage Options

All downloaders support three storage modes:

- `local` - Save to local filesystem only
- `s3` - Upload to S3 only
- `both` - Save locally and upload to S3 (default)

Example:
```bash
rake granblue:export:summon_images[2040001000,false,true,s3]
```

## Environment Variables

Common environment variables used by utilities:

- `TEST=true` - Run in test mode (no actual changes)
- `VERBOSE=true` - Enable detailed logging
- `FORCE=true` - Force re-download/re-process even if data exists

## Troubleshooting

### Common Issues

1. **404 errors during download**: The asset may not exist on the game server yet
2. **Wiki parse errors**: The wiki page format may have changed
3. **Import validation errors**: Check CSV format matches expected schema
4. **S3 upload failures**: Verify AWS credentials and bucket permissions

### Debug Mode

Most utilities support debug/verbose mode:

```bash
# Verbose output for debugging
rake granblue:export:character_images[3040001000,false,true]

# Test mode to simulate operations
rake granblue:import_data TEST=true VERBOSE=true
```

## Contributing

When adding new utilities:

1. Extend the appropriate base class (`BaseDownloader`, `BaseImporter`, etc.)
2. Follow the existing naming conventions
3. Add corresponding rake task in `lib/tasks/`
4. Update this documentation

## Support

For issues or questions about these utilities, check:

1. The specific utility's documentation
2. The rake task help: `rake -T granblue`
3. Rails logs for detailed error messages
4. AWS S3 logs for storage issues