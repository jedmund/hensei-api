# Rake Tasks Documentation

Complete reference for all available rake tasks in the hensei-api project. These tasks handle data management, image downloading, wiki synchronization, and various maintenance operations.

## Quick Reference

```bash
# List all available tasks
rake -T

# List Granblue-specific tasks
rake -T granblue

# List export tasks
rake -T export

# Get detailed help for a task
rake -D granblue:import_data
```

## Image Download Tasks

### Character Images

#### `granblue:export:character_images`
Download character images with all variants and sizes.

```bash
# Download all characters
rake granblue:export:character_images

# Download specific character
rake granblue:export:character_images[3040001000]

# With options: [id,test_mode,verbose,storage,size]
rake granblue:export:character_images[3040001000,false,true,s3,grid]

# Test mode (simulate)
rake granblue:export:character_images[,true,true]

# Download only specific size for all
rake granblue:export:character_images[,false,true,both,detail]
```

**Parameters:**
- `id`: Granblue ID or empty for all
- `test_mode`: true/false (default: false)
- `verbose`: true/false (default: true)
- `storage`: local/s3/both (default: both)
- `size`: main/grid/square/detail (default: all)

### Weapon Images

#### `granblue:export:weapon_images`
Download weapon images including elemental variants.

```bash
# Download all weapons
rake granblue:export:weapon_images

# Download specific weapon
rake granblue:export:weapon_images[1040001000]

# S3 only, grid size
rake granblue:export:weapon_images[1040001000,false,true,s3,grid]
```

**Parameters:** Same as character_images

### Summon Images

#### `granblue:export:summon_images`
Download summon images with uncap variants.

```bash
# Download all summons
rake granblue:export:summon_images

# Download specific summon
rake granblue:export:summon_images[2040001000]

# Local storage only
rake granblue:export:summon_images[2040001000,false,true,local]
```

**Parameters:** Same as character_images

### Job Images

#### `granblue:export:job_images`
Download job images with gender variants (wide and zoom formats).

```bash
# Download all jobs
rake granblue:export:job_images

# Download specific job
rake granblue:export:job_images[100401]

# Download only zoom images
rake granblue:export:job_images[100401,false,true,both,zoom]

# Download only wide images
rake granblue:export:job_images[,false,true,both,wide]
```

**Parameters:** Same as character_images, but size is wide/zoom

### Bulk Download

#### `granblue:download_all_images`
Download all images for a type with parallel processing.

```bash
# Download with parallel threads
rake granblue:download_all_images[character,4]
rake granblue:download_all_images[weapon,8]
rake granblue:download_all_images[summon,4]
rake granblue:download_all_images[job,2]

# Download specific size with threads
rake granblue:download_all_images[character,4,grid]
rake granblue:download_all_images[weapon,8,main]
```

**Parameters:**
- `object`: character/weapon/summon/job
- `threads`: Number of parallel threads (default: 4)
- `size`: Specific size to download (optional)

## Data Import Tasks

### Import from CSV

#### `granblue:import_data`
Import character, weapon, and summon data from CSV files.

```bash
# Import all CSV files from db/seed/updates/
rake granblue:import_data

# Test mode - validate without importing
rake granblue:import_data TEST=true

# Verbose output
rake granblue:import_data VERBOSE=true

# Both test and verbose
rake granblue:import_data TEST=true VERBOSE=true
```

**CSV Location:** `db/seed/updates/`
**File naming:** `{type}_YYYYMMDD.csv`

## Wiki Data Tasks

### Fetch Wiki Data

#### `granblue:fetch_wiki_data`
Fetch and store wiki data for game objects.

```bash
# Fetch all characters (default)
rake granblue:fetch_wiki_data

# Fetch specific type
rake granblue:fetch_wiki_data type=Weapon
rake granblue:fetch_wiki_data type=Summon
rake granblue:fetch_wiki_data type=Character

# Fetch specific item
rake granblue:fetch_wiki_data type=Character id=3040001000
rake granblue:fetch_wiki_data type=Weapon id=1040001000

# Force re-fetch even if data exists
rake granblue:fetch_wiki_data force=true
rake granblue:fetch_wiki_data type=Summon force=true
```

**Parameters:**
- `type`: Character/Weapon/Summon (default: Character)
- `id`: Specific Granblue ID (optional)
- `force`: true/false - Re-fetch even if wiki_raw exists

## Export URL Tasks

### Job URLs

#### `granblue:export:job`
Export list of job image URLs to text file.

```bash
# Export icon URLs
rake granblue:export:job[icon]

# Export portrait URLs
rake granblue:export:job[portrait]
```

**Output:** `export/job-{size}.txt`

### Export All URLs

#### `granblue:export:all`
Export all asset URLs for batch downloading.

```bash
# Export all URL lists
rake granblue:export:all

# Creates files in export/
# - character-*.txt
# - weapon-*.txt
# - summon-*.txt
# - job-*.txt
```

## Preview Tasks

### Generate Previews

#### `previews:generate_all`
Generate preview images for all parties without previews.

```bash
# Generate missing previews
rake previews:generate_all

# Processes parties with pending/failed/nil preview_state
# Uploads to S3: previews/{shortcode}.png
```

#### `previews:regenerate_all`
Regenerate preview images for all parties.

```bash
# Regenerate all previews (overwrites existing)
rake previews:regenerate_all
```

## Database Tasks

### Database Management

#### `database:backup`
Create database backup.

```bash
# Create timestamped backup
rake database:backup

# Output: backups/hensei_YYYYMMDD_HHMMSS.sql
```

#### `database:restore`
Restore database from backup.

```bash
# Restore from latest backup
rake database:restore

# Restore specific backup
rake database:restore[backups/hensei_20240315_120000.sql]
```

### Deployment Tasks

#### `deploy:post`
Run post-deployment tasks.

```bash
# Run all post-deployment tasks
rake deploy:post

# Includes:
# - Database migrations
# - Data imports
# - Asset compilation
# - Cache clearing
```

## Utility Tasks

### Download Images

#### `granblue:download_images`
Legacy task for downloading images.

```bash
# Download images (legacy)
rake granblue:download_images
```

**Note:** Prefer using the newer export tasks.

### Export Accessories

#### `granblue:export:accessories`
Export accessory data and images.

```bash
# Export all accessories
rake granblue:export:accessories
```

## Task Patterns and Options

### Common Parameters

Most tasks support these common parameters:

| Parameter | Values | Description |
|-----------|--------|-------------|
| `test_mode` | true/false | Simulate without making changes |
| `verbose` | true/false | Enable detailed logging |
| `storage` | local/s3/both | Storage destination |
| `force` | true/false | Force operation even if data exists |

### Environment Variables

Tasks can use environment variables:

```bash
# Test mode
TEST=true rake granblue:import_data

# Verbose output
VERBOSE=true rake granblue:import_data

# Force re-processing
FORCE=true rake granblue:fetch_wiki_data

# Custom environment
RAILS_ENV=production rake granblue:export:character_images
```

### Parameter Passing

Two ways to pass parameters:

1. **Bracket notation** (for defined parameters):
```bash
rake task_name[param1,param2,param3]
```

2. **Environment variables** (for options):
```bash
TEST=true VERBOSE=true rake task_name
```

### Skipping Parameters

Use commas to skip parameters:

```bash
# Skip ID, set test_mode=true, verbose=true
rake granblue:export:character_images[,true,true]

# Skip ID and test_mode, set verbose=true, storage=s3
rake granblue:export:weapon_images[,,true,s3]
```

## Best Practices

### 1. Test Before Running

Always test operations first:

```bash
# Test mode
rake granblue:import_data TEST=true

# Verify output
rake granblue:export:character_images[,true,true]

# Then run for real
rake granblue:export:character_images
```

### 2. Use Parallel Processing

For bulk operations, use parallel threads:

```bash
# Good - parallel
rake granblue:download_all_images[character,8]

# Less efficient - sequential
rake granblue:export:character_images
```

### 3. Monitor Long-Running Tasks

Use verbose mode and logs:

```bash
# Enable verbose
rake granblue:export:character_images[,false,true]

# Watch logs in another terminal
tail -f log/development.log
```

### 4. Batch Large Operations

Break large operations into chunks:

```bash
# Instead of all at once
rake granblue:export:character_images

# Process specific batches
rake granblue:export:character_images[3040001000]
rake granblue:export:character_images[3040002000]
```

### 5. Check Storage Space

Before bulk downloads:

```bash
# Check local space
df -h

# Check S3 usage
aws s3 ls s3://bucket-name/ --recursive --summarize
```

## Scheduling Tasks

### Cron Jobs

Example crontab entries:

```bash
# Daily wiki data fetch at 2 AM
0 2 * * * cd /app && rake granblue:fetch_wiki_data

# Weekly image download on Sunday at 3 AM
0 3 * * 0 cd /app && rake granblue:download_all_images[character,4]

# Hourly preview generation
0 * * * * cd /app && rake previews:generate_all
```

### Whenever Gem

Using whenever for scheduling:

```ruby
# config/schedule.rb
every 1.day, at: '2:00 am' do
  rake "granblue:fetch_wiki_data"
end

every :sunday, at: '3:00 am' do
  rake "granblue:download_all_images[character,4]"
end

every 1.hour do
  rake "previews:generate_all"
end
```

## Troubleshooting

### Task Not Found

```bash
# Check task exists
rake -T | grep task_name

# Ensure in correct directory
pwd  # Should be Rails root

# Load Rails environment
rake -T RAILS_ENV=development
```

### Permission Errors

```bash
# Check file permissions
ls -la lib/tasks/

# Fix permissions
chmod +x lib/tasks/*.rake

# Run with bundle
bundle exec rake task_name
```

### Memory Issues

```bash
# Increase memory for large operations
export RUBY_HEAP_MIN_SLOTS=500000
export RUBY_GC_MALLOC_LIMIT=90000000

rake granblue:download_all_images[character,2]
```

### Slow Performance

1. Use parallel processing
2. Run during off-peak hours
3. Process in smaller batches
4. Check network bandwidth
5. Monitor database connections

### Debugging

```bash
# Enable debug output
DEBUG=true rake task_name

# Rails console for testing
rails console
> load 'lib/tasks/task_name.rake'
> Rake::Task['task_name'].invoke

# Trace task execution
rake --trace task_name
```

## Creating Custom Tasks

### Basic Task Structure

```ruby
# lib/tasks/custom.rake
namespace :custom do
  desc "Description of the task"
  task :task_name, [:param1, :param2] => :environment do |t, args|
    # Set defaults
    param1 = args[:param1] || 'default'
    param2 = args[:param2] == 'true'

    # Task logic
    puts "Running with #{param1}, #{param2}"

    # Use Rails models
    Model.find_each do |record|
      # Process record
    end
  end
end
```

### Task with Dependencies

```ruby
namespace :custom do
  task :prepare do
    puts "Preparing..."
  end

  task :cleanup do
    puts "Cleaning up..."
  end

  desc "Main task with dependencies"
  task main: [:prepare, :environment] do
    puts "Running main task"

    # Main logic here

    Rake::Task['custom:cleanup'].invoke
  end
end
```

### Task with Error Handling

```ruby
namespace :custom do
  desc "Task with error handling"
  task safe_task: :environment do
    begin
      # Risky operation
      process_data
    rescue StandardError => e
      Rails.logger.error "Task failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      exit 1
    ensure
      # Cleanup
      cleanup_temp_files
    end
  end
end
```