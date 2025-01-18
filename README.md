# Hensei API

## Project Overview

Hensei is a Ruby on Rails API for managing Granblue Fantasy party configurations, providing comprehensive tools for team building, character management, and game data tracking.

## Prerequisites

- Ruby 3.3.7
- Rails 8.0.1
- PostgreSQL
- AWS S3 Account (for image storage)

## System Dependencies

- Ruby version manager (rbenv or RVM recommended)
- Bundler
- PostgreSQL
- Redis (for background jobs)
- ImageMagick (for image processing)

## Initial Setup

### 1. Clone the Repository

```bash
git clone https://github.com/your-organization/hensei-api.git
cd hensei-api
```

### 2. Install Ruby

Ensure you have Ruby 3.3.7 installed. If using rbenv:

```bash
rbenv install 3.3.7
rbenv local 3.3.7
```

### 3. Install Dependencies

```bash
gem install bundler
bundle install
```

### 4. Database Configuration

1. Ensure PostgreSQL is running
2. Create the database configuration:

```bash
rails db:create
rails db:migrate
```

### 5. AWS S3 Configuration

Hensei requires an AWS S3 bucket for storing images. Configure your credentials:

```bash
EDITOR=vim rails credentials:edit
```

Add the following structure to your credentials:

```yaml
aws:
  s3:
    bucket: your-bucket-name
    access_key_id: your-access-key
    secret_access_key: your-secret-key
    region: your-aws-region
```

### 6. Run Initial Data Import (Optional)

```bash
rails data:import
```

### 7. Start the Server

```bash
rails server
```

## Environment Variables

While most configurations use Rails credentials, you may need to set:

- `DATABASE_URL`
- `RAILS_MASTER_KEY`
- `REDIS_URL`

## Performance Considerations

- Use Redis for caching
- Background jobs managed by Sidekiq
- Ensure PostgreSQL is optimized for full-text search

## Security

- Always use `rails credentials:edit` for sensitive information
- Keep your `master.key` secure and out of version control
- Regularly update dependencies

## Deployment

Recommended platforms:
- Railway.app (We use this)i98-i
- Heroku
- DigitalOcean App Platform

Deployment steps:
1. Precompile assets: `rails assets:precompile`
2. Run migrations: `rails db:migrate`
3. Start the server with a production-ready web server like Puma

## Troubleshooting

- Ensure all credentials are correctly set
- Check PostgreSQL and Redis connections
- Verify AWS S3 bucket permissions

## License

## License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0-only) with additional non-commercial restrictions.

Key points:
- You are free to use and modify the software for non-commercial purposes
- Any modifications must be shared under the same license
- You must provide attribution to the original authors
- No warranty is provided

See the LICENSE file for full details.

## Contact

For support, please open an issue on the GitHub repository.
