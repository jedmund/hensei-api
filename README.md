# Hensei API

## Project Overview

Hensei is a Ruby on Rails API for managing Granblue Fantasy party configurations, providing comprehensive tools for team building, character management, and game data tracking.

## Prerequisites

- Ruby 3.4.4
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

This project is licensed under the GNU Affero General Public License v3.0 with a non-commercial use condition. See [LICENSE](LICENSE) for the full terms.

In short:
- You can use, study, modify and share the code for non-commercial purposes.
- If you modify it and share it or run it as a service others can use, you must publish your source code under the same terms.
- You can't use it, or anything built from it, for commercial purposes (selling it, charging for access, or running it with ads or paid features) without permission.
- There's no warranty.

## Contact

For support, please open an issue on the GitHub repository.

## Shared gacha simulations

The public, stateless gacha routes use the existing version prefix (`/api/v1`
locally, `/v1` in production):

- `GET /gacha/catalogue?mode=premium&season=formal&q=Europa` returns typed eligible targets and supported options. Omit `q` to retrieve the whole selected pool.
- `POST /gacha/simulations` performs fixed draws; over 10,000 draws returns HTTP 202 with a random job token.
- `POST /gacha/until` samples the waiting time for a natural-drop target, including final-purchase overshoot.
- `POST /gacha/odds` returns analytical probability, expected copies and first 50/90/95% attainment draw counts. A null threshold means it exceeds one trillion draws.
- `GET /gacha/jobs/:token` returns queued/running/complete/failed status. Unknown and expired jobs return 404.

Example body (replace the target with a catalogue identity):

```json
{
  "mode": "legend",
  "season": "formal",
  "purchase": "ten",
  "draws": "300",
  "target": "Weapon:00000000-0000-0000-0000-000000000001",
  "copies": 4,
  "comparison": "at_least",
  "rateups": [{"identity": "Weapon:00000000-0000-0000-0000-000000000001", "percent": "0.3"}],
  "seed": "optional-replay-seed"
}
```

Modes: premium, legend, flash, classic, classic_ii, classic_iii. Seasons:
valentines, summer, halloween, holiday, formal; Classic rejects seasons.
`purchase` defaults to `ten`; `singles` uses ordinary slots throughout. Ten-draw
counts must be multiples of ten. Draw defaults to 300; Until/Odds default to one
copy, Odds to `at_least`. Fixed draws support 1–1,000,000, Odds 1–1,000,000,000,000,
and requested copies 1–1,000. Until has no draw ceiling. Custom rates are SSR
percentages (`0.3` = 0.3%), not probability fractions. Zero rates exclude targets.

Results include normalized configuration, seed, catalogue SHA-256 fingerprint,
and engine version. Replay requires matching inputs, catalogue, engine and Ruby
version (currently Ruby 3.4.4); old TypeScript seeds are not compatible. Draw
counts, obtained copies, aggregates and money are decimal strings. Ordered
results are included through 300 draws, then only aggregates. Compiled jobs and
results expire in Redis one hour after acceptance and hold a captured catalogue;
workers never reload it. Treat job tokens as temporary result-access capabilities.

The compiler uses BigDecimal category budgets, inferred from the supplied game
table fixture: R shares 12:42:25, SR 5:6:4, SSR weapons:summons 11:4. Selected-gala
limited residual weapons have weight 2. Custom rates deduct from their SSR
category; excess borrows proportionally from the other category. Guaranteed
slots preserve SSR rates and allocate the remaining probability to SR categories.
These are **hypothetical catalogue simulations**, not a claim of current banner
membership or exact hidden probabilities. Zodiac rotations and spark exchanges
are not modeled. The copied evidence fixture tests displayed-rate truncation.

Catalogue snapshots are immutable, refreshed on demand every 15 minutes and
retained for at most one hour if refresh fails. Empty/missing catalogue service
returns 503. Invalid inputs return 422. The separate per-client-IP computation
limit defaults to 60/minute (`GACHA_REQUESTS_PER_MINUTE`) and applies even when
general `RATE_LIMIT_MODE=log`. It uses `ClientIpResolver`, the shared Redis limit
store, and HTTP 429 with `Retry-After: 60`. Job polling does not consume the
computation limit. Logs include action duration, catalogue age, job failures and
exchange quote age. Existing platform monitoring should alert on these signals.

Run Redis and Sidekiq with the API. The daily `GachaSimulation::ExchangeRateJob`
fetches Frankfurter's USD/JPY quote with `providers=ecb` at 17:00 UTC. On initial
rollout, prime it with `bundle exec rails runner 'GachaSimulation::ExchangeRateJob.perform_async'`.
Failure preserves the last successful quote; any older quote is labeled stale,
and quotes older than seven days omit USD. Conversion is JPY / JPY-per-USD.
`GACHA_CRYSTALS_PER_TEN` defaults to 3000 and `GACHA_JPY_PER_TEN` to 3150.
Cash values are purchase estimates; USD excludes payment-provider conversion
charges and is not a PayPal checkout quote.

Deploy this API before the Siero CLI/Discord and `/gacha` web clients. This branch
includes the prior reconciled catalogue work; no new schema/catalogue/identity
migration is introduced by the gacha service. Shared authenticated saved settings
remain a subsequent integration with the verified Discord identity contract.

Validation on the restored local catalogue found 2,321 typed items and four
Formal-exclusive recruitment weapons: Engagement Snowflake (Europa), Scheherazade
(Fraux), Marriage Sharkbell (Meg and Mari), and Bridekeeper (Ilsa). Other Formal
flags overlap ordinary availability and are deduplicated by typed identity.

Sources: [Formal catalogue](https://gbf.wiki/Category:Formal_Characters),
[Frankfurter](https://frankfurter.dev/),
[PayPal currency conversion](https://www.paypal.com/us/cshelp/article/where-can-i-find-paypals-currency-calculator-and-exchange-rates-help109).

Local verification (2026-10-02): focused gacha RSpec passed 19 examples; the
integrated full API suite passed 3,323 examples with two pending. Full RuboCop
passed 818 files. Integration also fixes the existing cross-party
`grid_weapons/resolve` nondeterminism by anchoring authorization to the first
submitted conflict, while retaining party-scoped deletion. Live local checks
used a read-only restored-database connection: all six modes/all five applicable
seasons, four Formal-exclusive additions, seed replay, one million queued draws,
and a sampled 325,480,450-draw Until run. The daily ECB provider returned a dated
quote successfully.
