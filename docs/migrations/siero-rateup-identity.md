# Siero rate-up identity transition

Deploy the additive schema before the compatible bot. `gacha_rateups.drawable_type`
is nullable text, restricted to `Weapon` or `Summon`; `drawable_id` is a nullable
UUID. Both must be null or both present. Discord `user_id` remains a string,
`rate` remains decimal, and `gacha_id` and timestamps remain intact. The index
on `(user_id, drawable_type, drawable_id)` supports per-user settings reads.
There is deliberately no uniqueness constraint during this transition.

The polymorphic reference has no cross-table foreign key. Every new bot write
must verify the item exists in the matching table, inside its settings transaction.
Catalogue deletion must preserve saved settings and surface a missing-item error;
do not silently delete saved settings. Run periodic reconciliation to detect drift.

## Deployment and reconciliation

1. Before deployment, capture aggregate row counts and data quality from production
   with `bundle exec rails siero:rateup_preflight`. It supports the legacy schema,
   reporting `schema_ready: false` before additive columns exist. Its nonzero status
   before schema/backfill is expected and does not prevent applying the additive migration. Local findings do
   not establish production safety. This code was tested only
   on a disposable local database; production was not queried.
2. The normal Hensei deployment runs `db:migrate:with_data`. The data migration fills
   only fully empty pairs whose legacy row points to an existing weapon or summon.
   It reports aggregate counts and preserves duplicates, unmappable rows and conflicts.
3. Run `bundle exec rails siero:rateup_preflight` with the intended database URL.
   This task performs only SELECTs, emits aggregate JSON, and exits unsuccessfully
   if any repair/backfill is still needed. Counts may overlap; they are not partitions.
   `new_only` includes valid and missing new targets; `missing_new_item` identifies
   missing targets separately. Null `gacha_id` is permitted for new-only settings.
4. Repair orphaned legacy references, unsupported source types, missing targets,
   conflicting identities and duplicate settings through an explicitly reviewed
   process. Preserve user choices and percentages; do not choose an arbitrary winner.
   Duplicate counts group by Discord user and effective typed UUID, including
   legacy mappings for rows not yet backfilled. No task deletes or overwrites conflicts.
5. Stop old writers, then run `bundle exec rails siero:rateup_backfill` even if the
   recorded data migration already ran. Old writers can insert new legacy-only rows.
   The backfill task exits nonzero after committing safe updates if blockers remain;
   the recorded data migration reports blockers without aborting safe deployment.
   Rerun preflight and require `ready_for_cutover: true` before compatible bot cutover.
   Compare total rows and the saved user/rate/timestamp values to the baseline.

Backfill runs in one transaction and locks rate-ups against writes during reconciliation,
serializing reruns. It verifies every row's id, legacy reference, Discord user, decimal
rate and timestamp remain identical. It validates catalogue existence when updating;
a shared lock on legacy and item tables prevents concurrent catalogue writes during
the transaction. Catalogue deletion after commit can create dangling identities because
there is no FK. Quiesce catalogue deletion during final reconciliation and cutover.
Plan the brief write lock and memory proportional to saved settings in deployment.
Preflight sees one statement snapshot for item quality; duplicate counts use a separate
SELECT. Quiesce writers for a consistent final report.

## Rollback

Application rollback keeps both columns and their populated values. Both migrations
refuse destructive down migration: new-only identity cannot be rebuilt from `gacha_id`.
A legacy bot cannot understand new-only settings. Use a compatible prior build, or
explicitly reconcile those settings before considering legacy code; do not erase them.
Mandatory pairs, uniqueness, and legacy-table removal belong to a later cleanup.

## Validation

Use a newly created uniquely named disposable PostgreSQL database, setting both
`DATABASE_URL=postgres://localhost/<disposable-name>` and `RAILS_ENV=test` on every
Rails/RSpec command. Load schema, run migrations, then run
`bundle exec rspec spec/migrations/rateup_identity_spec.rb` and `bundle exec rspec`.
Never run these against the default test/development database. Focused specs may pass
while SimpleCov exits unsuccessfully for the repository-wide 60% threshold.
