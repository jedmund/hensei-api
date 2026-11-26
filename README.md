# Hensei API

## Project Overview

The Rails API behind [granblue.team](https://granblue.team), a team builder for Granblue Fantasy. It stores parties, users and their collections, and the catalogue of characters, weapons and summons. The web app ([jedmund/hensei-web](https://github.com/jedmund/hensei-web)) and the browser extension ([jedmund/hensei-extractor](https://github.com/jedmund/hensei-extractor)) both talk to it.

## Prerequisites

- Ruby 3.4.4 (see `.ruby-version`), with a version manager such as rbenv
- Bundler
- PostgreSQL
- Redis, for Sidekiq background jobs
- AWS S3 access, only for image uploads and the image download tasks
- ImageMagick, only for the event banner rake tasks

## Initial Setup

### 1. Clone the Repository

```bash
git clone https://github.com/jedmund/hensei-api.git
cd hensei-api
```

### 2. Install Ruby

Ensure you have Ruby 3.4.4 installed. If using rbenv:

```bash
rbenv install 3.4.4
rbenv local 3.4.4
```

### 3. Install Dependencies

```bash
gem install bundler
bundle install
```

### 4. Database Configuration

1. Ensure PostgreSQL is running
2. Create the database, load the schema and run the seeds in `lib/seeds/`:

```bash
bin/rails db:setup
```

After pulling new migrations, run `bin/rails db:migrate:with_data`. That runs the schema migrations and the data migrations in `db/data/`.

Without `DATABASE_URL`, the test database is `hensei_test` in the main checkout and `hensei_test_<hash>` in each linked git worktree, so parallel worktrees don't share one. A new worktree needs it created once:

```bash
RAILS_ENV=test bin/rails db:create db:schema:load
```

### 5. AWS S3 Configuration

Images live in the `siero-img` S3 bucket. `AwsService` looks for credentials in this order:

1. Rails credentials (`bin/rails credentials:edit`, which needs the master key):

   ```yaml
   aws:
     access_key_id: your-access-key
     secret_access_key: your-secret-key
     region: your-aws-region
     bucket_name: your-bucket-name
   ```

2. `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` and `AWS_BUCKET_NAME` environment variables.
3. The AWS SDK's default chain, such as an `aws login` session. The bucket then defaults to `siero-img`.

You can skip this if you aren't working on image uploads or downloads.

### 6. Run Initial Data Import (Optional)

This imports weapon, summon and character CSVs that you put in `db/seed/updates` (the repo only has `.example` files there):

```bash
bin/rails granblue:import_data
```

### 7. Start the Server

```bash
bin/rails server          # http://localhost:3000
bundle exec sidekiq       # background and scheduled jobs
```

In development and test, routes are mounted at `/api/v1` (`/v1` in production). Point the web app at this server with `PUBLIC_SIERO_API_URL=http://localhost:3000`.

### 8. Run the Tests and Linter

```bash
bundle exec rspec
bundle exec rubocop
```

Running a single spec file fails the SimpleCov minimum coverage check even when the specs pass. That's expected.

### Testing from a phone

Connect your computer and phone to the same network. Find your computer's local
network address: `ipconfig getifaddr en0` on macOS, `hostname -I` on Linux, or
`ipconfig` on Windows (look for the IPv4 address).
For an address of `192.168.1.50`, start the development API with:

```bash
DEV_CORS_ORIGINS=http://192.168.1.50:5174 bin/rails server -b 0.0.0.0
```

`DEV_CORS_ORIGINS` accepts comma-separated frontend origins, including the scheme
and port, with no path or trailing slash. It adds only those exact origins in
development; it is ignored in other environments. Restart the API after changing
it. Rails already allows IP address hosts in development.

In the web app, set `PUBLIC_SIERO_API_URL=http://192.168.1.50:3000` in the existing
gitignored `.env.local` file, then run `pnpm dev:mobile`. Open
`http://192.168.1.50:5174` on your phone. The web app adds `/api/v1` and `/oauth`
to the API base URL itself. See the web app README for image configuration and
troubleshooting.

## Environment Variables

While most configurations use Rails credentials, you may need to set:

- `DATABASE_URL`
- `RAILS_MASTER_KEY`: required in production only. You don't need it to work locally; use the `AWS_*` variables below instead of the encrypted credentials.
- `REDIS_URL` (defaults to `redis://localhost:6379/0`)
- `AWS_*` (see AWS S3 Configuration above)
- `RATE_LIMIT_MODE`: `log` (the default) only logs clients that would be rate limited; `enforce` returns 429s
- `API_INTERNAL_SECRET`: a secret shared with the web app; set the same value on both
- `DEV_CORS_ORIGINS` (optional, development only; see phone testing above)

## Performance Considerations

- Use Redis for caching
- Background jobs managed by Sidekiq
- Ensure PostgreSQL is optimized for full-text search

## Security

- Always use `rails credentials:edit` for sensitive information
- Keep your `master.key` secure and out of version control
- Regularly update dependencies

## Deployment

The API runs anywhere that can host a Rails app with PostgreSQL and Redis. It needs two processes: the Puma web server and a Sidekiq worker.

1. Set `RAILS_ENV=production`, `DATABASE_URL`, `REDIS_URL` and `RAILS_MASTER_KEY`. The encrypted credentials in this repo belong to granblue.team, so for your own copy, delete `config/credentials.yml.enc` and run `bin/rails credentials:edit` to create a new file and key.
2. Add your web app's origin to the production list in `config/initializers/cors.rb`. Only the origins listed there can call the API from a browser.
3. Install gems without the development and test groups:

   ```bash
   BUNDLE_WITHOUT=development:test bundle install
   ```

4. Run the schema and data migrations before starting each new version:

   ```bash
   bin/rails db:migrate:with_data
   ```

5. Start both processes:

   ```bash
   bundle exec puma -C config/puma.rb   # listens on $PORT, default 3000
   bundle exec sidekiq
   ```

In production, routes are mounted at `/v1` instead of `/api/v1`. Set `RAILS_LOG_TO_STDOUT=1` to log to standard output.

## Troubleshooting

- Ensure all credentials are correctly set
- Check PostgreSQL and Redis connections
- Verify AWS S3 bucket permissions

## License

This project is licensed under the GNU Affero General Public License v3.0 with a non-commercial use condition. See [LICENSE](LICENSE) for the full terms.

In short:
- You can use, study, modify and share the code for non-commercial purposes.
- If you modify it and share it or run it as a service others can use, you must publish your source code under the same terms.
- You can't use it, or anything built from it, for commercial purposes (selling it, charging for access, or running it with ads or paid features) without permission.
- There's no warranty.

## Contact

For support, please open an issue on the GitHub repository.
