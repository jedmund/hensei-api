# Weapon-skill pipeline: agent manual

This directory coordinates the work that replaces hensei-api's weapon-skill import writers with one deterministic build:
- stored sources → pure build → committed curation overlay → one precedence rule.
- The product plan is `docs/prds/weapon-skill-data-pipeline-prd.md` in the workspace repo.

This manual and the briefs are self-contained. An agent working from a clone of this repo needs nothing else.

## The first milestone is parity

The new pipeline must reproduce today's calculator data **exactly** before anything gets more correct.
- "Today's data" is the committed parity baseline, `data/weapon_skill_parity/baseline.json`: every skill version's resolved rows, as the calculator reads them.
- `bin/rails granblue:skill_parity` compares a database against it and prints a per-weapon diff.

**Baseline facts (2026-10-15):**
- 3,737 versions on 1,862 weapons.
- **The offline description extractor reproduces it exactly**, and gives the same result run twice.
- **A full reparse with wiki calls changes 103 versions on 81 weapons**, all of them state that only migrations put there:
  - skill sizes and family links (Excelsior, Crux, Might…);
  - unlock gates;
  - ten fifth-slot Majesty skills;
  - July recovery rows;
  - 26 tiers new on the wiki.

  W2 turns that list into curation.

## Ground rules

1. **Nothing lives only on one machine.**
   - Plans, briefs, contracts and classifications go in this directory.
   - Baselines and diffs go in `data/weapon_skill_parity/`.
   - Status goes on GitHub.
   - Don't leave results in a temp directory.
2. **Status on GitHub.**
   - **Tracking issue:** "Weapon-skill pipeline", label `pipeline`.
   - **Per-workstream issues:** label `pipeline:W<n>`.
   - **Comments:** comment when you start, when you're blocked, when you need a file you don't own, and when you open a PR.
3. **Your own databases.** Never use a shared `hensei_dev` or `hensei_test`. Run `bin/setup-pipeline-db W<n>`, which creates `hensei_pipeline_w<n>` (the catalogue) and `hensei_pipeline_w<n>_test` (empty, for rspec). Then export:
   ```sh
   export DATABASE_URL=postgres://localhost/hensei_pipeline_w<n>
   export CURATION_AUTO_EXPORT=0   # curation files change only by explicit export
   ```
   The script restores the latest `catalogue-YYYYMMDD` release asset, migrates, syncs curation and loads the golden fixtures (once W4 adds them). Restoring takes about 15 s.
   - **The dump:** game catalogue only, no user data. It's a **draft** release on `jedmund/hensei-api`, so it's private to repo collaborators; any machine with `gh` auth can download it.
   - Run the script again when the lead announces a new dump.
   - **Never** run rake tasks against `hensei_dev` from a pipeline branch. The dev curation auto-export would write that database's curation into your branch.
4. **Your own branch:** `pipeline/W<n>-<slug>`, from `main`, in its own worktree or clone.
5. **Deploy-safe PRs.**
   - Main deploys automatically. New code goes behind `WEAPON_SKILL_BUILD` or in the `WeaponSkills::` namespace.
   - Schema changes are additive.
   - Stack PRs only inside your workstream.
6. **Owned files only.** Your brief lists them. Anything else is a question on the tracking issue.
7. **Migration timestamps:** use your workstream's hour block (W0 `…09xxxx`, W1 `…10xxxx`, W2 `…11xxxx`, W3 `…12xxxx`, W4 `…13xxxx`, W5 `…14xxxx`, W6 `…15xxxx`, W7 `…16xxxx` on the day you start). For `db/schema.rb` and `db/data_schema.rb` conflicts, keep the higher version.
8. **Before every PR:**
   - `DATABASE_URL=postgres://localhost/hensei_pipeline_w<n>_test bundle exec rspec` (the full suite, against **your test database**. The test environment reads `DATABASE_URL`, so running rspec with the catalogue database exported would wipe it. A single file fails the coverage minimum, which is expected);
   - `bundle exec rubocop` on changed files;
   - `bin/rails granblue:skill_parity`. It must pass, or the PR refreshes the baseline and explains every change.
   - Curation changes also need `bin/rails granblue:weapon_skill_curation_drift`.
9. **Commits and PRs:**
   - Conventional Commits (`type(scope): summary`) with a short "why" body.
   - Stage by explicit path.
   - No AI or agent attribution.
   - The user merges.

## Workstreams

| ID | Workstream | Depends on | Brief |
|---|---|---|---|
| W0 | Contracts and tooling (lead) | — | [briefs/W0.md](briefs/W0.md) |
| W1 | Safety fixes and fetch dates | W0 | [briefs/W1.md](briefs/W1.md) |
| W2 | Migration-only state → curation | W0 | [briefs/W2.md](briefs/W2.md) |
| W3 | Stored sources | W0 | [briefs/W3.md](briefs/W3.md) |
| W4 | Goldens in CI | W0 | [briefs/W4.md](briefs/W4.md) |
| W5 | Key-skill parity | W0, W3 interface | [briefs/W5.md](briefs/W5.md) |
| W6a/b/c | Structure compiler, row compiler, per-version descriptions | W3 | written when wave 1 lands |
| W7 | Overlay v2 applier | W2 fragments | written when wave 1 lands |
| W8 | Integration, shadow, switch-over | W6, W7 | written when wave 2 lands |
| W9 | Golden recaptures (user) | — | see the PRD |
| W10 | Correctness changes | W8 | later |

## Contracts

W0 defines these; the other workstreams build against them.
- **Parity snapshot:**
  - key `weapon_granblue_id|position|ordinal|skill_name` → `{gate, frame: [modifier, series, size, multiplier_frame], data, effects}`, plus a `keys` section;
  - floats; rows sorted.
- **`BuildResult`** (`lib/weapon_skills/build_result.rb`): `Slot`, `Version` and `Row` structs with `identity`. A version's identity is `(weapon, position, ordinal)`; a row's is `(version, boost_type, condition)`.
- **Overlay v2:** [overlay-v2.md](overlay-v2.md), plus a JSON schema checked by a spec.
- **`SourceStore`:** `fetch(kind, key)` returns the body or raises `SourceMissing`; `put(kind, key, body, page_kind:)`.
- **Flag:** `WEAPON_SKILL_BUILD` = `off` | `shadow` | `write`.
