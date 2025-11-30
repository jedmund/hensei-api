# Image Downloaders Documentation

The downloader system provides a flexible framework for downloading game asset images from Granblue Fantasy servers. It supports multiple image sizes, variants, and storage backends (local filesystem and AWS S3).

## Architecture

### Base Downloader

All downloaders inherit from `BaseDownloader` which provides:
- Storage management (local, S3, or both)
- Download retry logic
- 404 error handling
- Verbose logging support
- Test mode for dry runs

### Available Downloaders

#### CharacterDownloader
Downloads character portrait images in multiple variants.

**Image Sizes:**
- `main` - Full character art (f/)
- `grid` - Medium portrait (m/)
- `square` - Small square icon (s/)
- `detail` - Detailed view (detail/)

**Variants:**
- `_01` - Base art
- `_02` - First uncap art
- `_03` - FLB (5★) art (if available)
- `_04` - ULB (6★) art (if available)

**Example:**
```ruby
downloader = Granblue::Downloaders::CharacterDownloader.new(
  "3040001000",
  storage: :both,
  verbose: true
)
downloader.download        # Downloads all sizes and variants
downloader.download("grid") # Downloads only grid size
```

#### WeaponDownloader
Downloads weapon images with elemental variations.

**Image Sizes:**
- `main` - Full weapon art (ls/)
- `grid` - Grid view (m/)
- `square` - Small icon (s/)

**Example:**
```ruby
downloader = Granblue::Downloaders::WeaponDownloader.new(
  "1040001000",
  storage: :s3,
  verbose: true
)
downloader.download
```

#### SummonDownloader
Downloads summon images including uncap variants.

**Image Sizes:**
- `main` - Full summon art (b/)
- `grid` - Grid view (m/)
- `square` - Small icon (s/)

**Variants:**
- Base art and uncap variations based on summon's max_level

**Example:**
```ruby
downloader = Granblue::Downloaders::SummonDownloader.new(
  "2040001000",
  storage: :local,
  verbose: true
)
downloader.download
```

#### JobDownloader
Downloads job class images with gender variants.

**Image Sizes:**
- `wide` - Wide format portrait
- `zoom` - Close-up portrait (1138x1138)

**Variants:**
- `_a` - Male variant
- `_b` - Female variant

**URLs:**
- Wide: `https://prd-game-a3-granbluefantasy.akamaized.net/assets_en/img/sp/assets/leader/m/{id}_01.jpg`
- Zoom: `https://media.skycompass.io/assets/customizes/jobs/1138x1138/{id}_{0|1}.png`

**Example:**
```ruby
downloader = Granblue::Downloaders::JobDownloader.new(
  "100401",
  storage: :both,
  verbose: true
)
downloader.download        # Downloads both wide and zoom with gender variants
downloader.download("zoom") # Downloads only zoom images
```

## Rake Tasks

### Download Images for Specific Items

```bash
# Character images
rake granblue:export:character_images[3040001000]
rake granblue:export:character_images[3040001000,false,true,s3,grid]

# Weapon images
rake granblue:export:weapon_images[1040001000]
rake granblue:export:weapon_images[1040001000,false,true,both,main]

# Summon images
rake granblue:export:summon_images[2040001000]
rake granblue:export:summon_images[2040001000,false,true,local]

# Job images
rake granblue:export:job_images[100401]
rake granblue:export:job_images[100401,false,true,both,zoom]
```

### Bulk Download All Images

```bash
# Download all images for a type with parallel processing
rake granblue:download_all_images[character,4]      # 4 threads
rake granblue:download_all_images[weapon,8,grid]    # 8 threads, grid only
rake granblue:download_all_images[summon,4,square]  # 4 threads, square only
rake granblue:download_all_images[job,2]            # 2 threads, all sizes

# Download all with specific parameters
rake granblue:export:character_images[,false,true,s3]  # All characters to S3
rake granblue:export:weapon_images[,true]               # Test mode
rake granblue:export:summon_images[,false,false,local]  # Local only, quiet
rake granblue:export:job_images[,false,true,both]       # Both storages
```

## Storage Options

### Local Storage
Files are saved to `Rails.root/download/`:
```
download/
├── character-main/
├── character-grid/
├── character-square/
├── character-detail/
├── weapon-main/
├── weapon-grid/
├── weapon-square/
├── summon-main/
├── summon-grid/
├── summon-square/
├── job-wide/
└── job-zoom/
```

### S3 Storage
Files are uploaded with the following key structure:
```
{object_type}-{size}/{filename}

Examples:
character-grid/3040001000_01.jpg
weapon-main/1040001000.jpg
summon-square/2040001000.jpg
job-zoom/100401_a.png
job-zoom/100401_b.png
```

### Storage Mode Selection
```ruby
storage: :local  # Save to filesystem only
storage: :s3     # Upload to S3 only
storage: :both   # Save locally AND upload to S3 (default)
```

## Parameters Reference

### Common Parameters
All downloaders accept these parameters:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `id` | String | required | Granblue ID of the item |
| `test_mode` | Boolean | false | Simulate downloads without downloading |
| `verbose` | Boolean | false | Enable detailed logging |
| `storage` | Symbol | :both | Storage mode (:local, :s3, :both) |
| `logger` | Logger | Rails.logger | Logger instance to use |

### Rake Task Parameters
For rake tasks, parameters are passed in order:

```bash
rake task_name[id,test_mode,verbose,storage,size]
```

Examples:
```bash
# All parameters
rake granblue:export:character_images[3040001000,false,true,both,grid]

# Skip parameters with commas
rake granblue:export:weapon_images[,true,true]  # All weapons, test mode, verbose

# Partial parameters
rake granblue:export:summon_images[2040001000,false,true,s3]
```

## Test Mode

Test mode simulates downloads without actually downloading files:

```ruby
# Ruby
downloader = Granblue::Downloaders::CharacterDownloader.new(
  "3040001000",
  test_mode: true,
  verbose: true
)
downloader.download

# Rake task
rake granblue:export:character_images[3040001000,true,true]
```

Output in test mode:
```
-> 3040001000
  (Test mode - would download images)
```

## Error Handling

### 404 Errors
When an image doesn't exist on the server, the downloader logs it and continues:
```
├ grid: https://example.com/image.jpg...
  404 returned  https://example.com/image.jpg
```

### Network Errors
Network errors are caught and logged, allowing the process to continue:
```ruby
begin
  download_to_local(url, path)
rescue OpenURI::HTTPError => e
  log_info "404 returned\t#{url}"
rescue StandardError => e
  log_info "Error downloading #{url}: #{e.message}"
end
```

## Best Practices

### 1. Use Parallel Processing for Bulk Downloads
```bash
# Good - uses multiple threads
rake granblue:download_all_images[character,8]

# Less efficient - sequential
rake granblue:export:character_images
```

### 2. Check Test Mode First
Before running bulk operations:
```bash
# Test first
rake granblue:export:character_images[,true,true]

# Then run for real
rake granblue:export:character_images[,false,true]
```

### 3. Use Specific Sizes When Needed
If you only need certain image sizes:
```bash
# Download only grid images (faster)
rake granblue:download_all_images[weapon,4,grid]

# Instead of all sizes
rake granblue:download_all_images[weapon,4]
```

### 4. Monitor S3 Usage
When using S3 storage:
- Check AWS costs regularly
- Use lifecycle policies for old images
- Consider CDN caching for frequently accessed images

## Custom Downloader Implementation

To create a custom downloader:

```ruby
module Granblue
  module Downloaders
    class CustomDownloader < BaseDownloader
      # Define available sizes
      SIZES = %w[large small].freeze

      # Required: specify object type
      def object_type
        'custom'
      end

      # Required: base URL for assets
      def base_url
        'https://example.com/assets'
      end

      # Required: map size to directory
      def directory_for_size(size)
        case size
        when 'large' then 'lg'
        when 'small' then 'sm'
        end
      end

      # Optional: custom download logic
      def download(selected_size = nil)
        # Custom implementation
        super
      end
    end
  end
end
```

## Troubleshooting

### Images Not Downloading
1. Check network connectivity
2. Verify the Granblue ID exists in the database
3. Ensure the asset exists on the game server
4. Check storage permissions (filesystem or S3)

### S3 Upload Failures
1. Verify AWS credentials are configured
2. Check S3 bucket permissions
3. Ensure bucket exists and is accessible
4. Check for S3 rate limiting

### Slow Downloads
1. Use parallel processing with more threads
2. Download specific sizes instead of all
3. Check network bandwidth
4. Consider using S3 only mode to avoid local I/O

### Debugging
Enable verbose mode for detailed output:
```bash
rake granblue:export:character_images[3040001000,false,true]
```

Check Rails logs:
```bash
tail -f log/development.log
```