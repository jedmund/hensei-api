# Shipping weapon-skill curation

The calculator's weapon-skill data (`weapon_skill_effects`, `weapon_skill_data` and
the override columns on `weapon_skill_versions`) is curated by hand: in the admin
editor, from golden panels, or with SQL. Hand edits are stamped `manually_edited_at`
(rows) or `overrides_edited_at` (versions), which reparse and the importers respect.

A hand edit in your local database doesn't reach prod by itself. In July 2026 a
month of curation was made locally, only partly exported and never applied to prod,
so it was lost when the dev database was later rebuilt from a prod backup. It had to
be rebuilt from commit messages (hensei-api #528).

## The overlay

Curation lives in `data/weapon_skill_curation/`, in the overlay v2 format
(`docs/weapon-skill-pipeline/overlay-v2.md`):

- `<series-slug>.json` holds the curation for weapons in that series; weapons with no
  series go in `_none.json`;
- `_canonical.json` holds canonical rows (no version), including key-scoped effects.

Each file has four sections:

- `versions`: overrides (`modifier_override`, `series_override`, `size_override`,
  `suppressed_boosts`);
- `effects` and `data`: curated rows;
- `ops`: structural changes. `remove_version`, `add_version`, `gate` (unlock level,
  uncap, transcendence stage) and `description` (the version's text). Each cites its
  source in `reason`.

Entries name their version by weapon `granblue_id`, skill name and ordinal. Within a
file they're sorted by weapon, skill and ordinal; the same entry in two files is an
error.

## The workflow

1. Curate locally and stamp the rows (the admin editor does this for you).
2. In development the overlay exports itself: saving or deleting a curated row
   rewrites `data/weapon_skill_curation/` after the request, or when a console, runner
   or rake process exits. Rake tasks that may write with `update_all` (data
   migrations, reparses) re-export on exit if anything drifted. Set
   `CURATION_AUTO_EXPORT=0` to turn it off. To export by hand:
   `bin/rails granblue:export_weapon_skill_curation`.
3. Check: `bin/rails granblue:weapon_skill_curation_drift`. It exits nonzero if this
   database has curation the overlay doesn't.
4. Commit `data/weapon_skill_curation/` with your change.

Ops aren't stamped in the database, so export can't produce them: it keeps every op
already in the files and refiles it by series. **Write ops by hand**, with a `reason`.
Gates, version text, and versions the build gets wrong (missing or extra) are ops.
Don't fix them with a data migration.

The auto-export won't overwrite the files while they hold entries your database lacks
(a teammate's curation, a curated row you deleted, or an op not applied here); it logs
a warning instead. Run `bin/rails granblue:sync_weapon_skill_curation` to pull those
in, or remove them from the files if the deletion was intentional.

Every deploy runs `db:migrate:with_data`, and the overlay sync is chained onto it
(`lib/tasks/weapon_skill_curation.rake`), so the committed overlay is applied to prod
on the next deploy. No hand-written data migration is needed for curation.

## What the sync does

1. **Validates every file** against `WeaponSkills::OverlaySchema` and checks for
   duplicate entries. Any error aborts the sync, and so the deploy, before anything is
   written. The message names the file and the entry.
2. **Applies the ops, in one transaction with everything else:** `remove_version`, then
   `add_version`, then `gate` and `description`.
   - Every op is idempotent. An op the database already reflects counts as "already in
     place".
   - `description` waits until the per-version text columns exist.
3. **Applies overrides.** Suppression deletes uncurated rows of the suppressed types,
   and reparse won't regenerate them.
4. **Applies curated rows.** It creates missing rows, and updates a row only when the
   overlay's stamp is newer than the row's. A later edit made in prod's admin editor
   wins over an older commit. It never deletes curated rows. To remove a generated row,
   curate a `suppressed_boosts` override on its version.

Entries it can't match (for example, a skill renamed since the export) are logged
instead of failing the deploy. A second sync reports 0 ops applied, 0 created and
0 updated.

Prod-only edits made in the admin editor are not in the overlay until someone exports
from a database that has them. `granblue:weapon_skill_curation_drift` reports overlay
entries missing locally as "unapplied"; run `granblue:sync_weapon_skill_curation` to
bring a local database up to date.

## Fragments and the v1 file

`data/weapon_skill_curation/pending/*.json` holds fragments in the same format that
haven't been filed yet. The sync doesn't read them. `bin/rails
granblue:split_weapon_skill_curation` files them, and the v1 single file
`data/weapon_skill_curation.json` if it's still there, into the series files. When two
entries share an identity, the newer stamp wins. The task can be re-run.
