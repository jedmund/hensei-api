# Shipping weapon-skill curation

The calculator's weapon-skill data (`weapon_skill_effects`, `weapon_skill_data` and
the override columns on `weapon_skill_versions`) is curated by hand: in the admin
editor, from golden panels, or with SQL. Hand edits are stamped `manually_edited_at`
(rows) or `overrides_edited_at` (versions), which reparse and the importers respect.

A hand edit in your local database doesn't reach prod by itself. In July 2026 a
month of curation was made locally, only partly exported and never applied to prod,
so it was lost when the dev database was later rebuilt from a prod backup. It had to
be rebuilt from commit messages (hensei-api #528).

## The workflow

1. Curate locally and stamp the rows (the admin editor does this for you).
2. Export: `bin/rails granblue:export_weapon_skill_curation`. This writes every
   curated row to `data/weapon_skill_curation.json`, keyed by weapon granblue_id
   and skill name.
3. Check: `bin/rails granblue:weapon_skill_curation_drift`. It exits nonzero if
   this database has curation the snapshot doesn't.
4. Commit `data/weapon_skill_curation.json` with your change.

Every deploy runs `db:migrate:with_data`, and the snapshot sync is chained onto it
(`lib/tasks/weapon_skill_curation.rake`), so the committed snapshot is applied to
prod on the next deploy. No hand-written data migration is needed for curation.

## What the sync does

- Creates curated rows that are missing.
- Updates a row only when the snapshot's stamp is newer than the row's. A later edit
  made in prod's admin editor wins over an older commit.
- Never deletes curated rows. To remove a generated row, curate a `suppressed_boosts`
  override on its version: the sync deletes uncurated rows of suppressed types, and
  reparse won't regenerate them.
- Logs rows it can't match (for example, a skill renamed since the export) instead of
  failing the deploy.

Prod-only edits made in the admin editor are not in the snapshot until someone
exports from a database that has them. `granblue:weapon_skill_curation_drift`
reports snapshot rows missing locally as "unapplied"; run
`granblue:sync_weapon_skill_curation` to bring a local database up to date.

Larger structural repairs (renaming skills, creating versions) still belong in a
data migration under `db/data/`.
