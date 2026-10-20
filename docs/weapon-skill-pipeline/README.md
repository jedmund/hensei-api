# Weapon-skill pipeline: agent manual

This directory coordinates the work that replaces hensei-api's weapon-skill import writers with one deterministic build:
- stored sources → pure build → committed curation overlay → one precedence rule.
- The product plan is `docs/prds/weapon-skill-data-pipeline-prd.md` in the workspace repo.

**Coming back to this?** Start with [report.md](report.md): where the calculator stands, what we learned, and where to pick up.

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
2. **Talk to each other.**
   - **Live coordination:** use `ListAgents` to find the other workstream agents (named by workstream) and `SendMessage` them directly. Use it for interface questions, "I need a file you own", and "my change affects yours".
   - **The record:** anything decided goes on the GitHub issue too, so it outlives the session.
   - **The lead:** message the lead when you're blocked or done.
3. **Status on GitHub.**
   - **Tracking issue:** "Weapon-skill pipeline", label `pipeline`.
   - **Per-workstream issues:** label `pipeline:W<n>`.
   - **Comments:** comment when you start, when you're blocked, when you need a file you don't own, and when you open a PR.
4. **Your own databases.** Never use a shared `hensei_dev` or `hensei_test`. Run `bin/setup-pipeline-db W<n>`, which creates `hensei_pipeline_w<n>` (the catalogue) and `hensei_pipeline_w<n>_test` (empty, for rspec). Then export:
   ```sh
   export DATABASE_URL=postgres://localhost/hensei_pipeline_w<n>
   export CURATION_AUTO_EXPORT=0   # curation files change only by explicit export
   ```
   The script restores the latest `catalogue-YYYYMMDD` release asset, migrates, syncs curation and loads the golden fixtures (once W4 adds them). Restoring takes about 15 s.
   - **The dump:** game catalogue only, no user data. It's a **draft** release on `jedmund/hensei-api`, so it's private to repo collaborators; any machine with `gh` auth can download it.
   - Run the script again when the lead announces a new dump.
   - **Never** run rake tasks against `hensei_dev` from a pipeline branch. The dev curation auto-export would write that database's curation into your branch.
5. **Your own branch:** `pipeline/W<n>-<slug>`, branched from **`origin/pipeline/integration`**, in its own worktree or clone.
   - `pipeline/integration` is W0 plus every workstream the lead has reviewed. Nobody merges into it but the lead.
   - Open your PR against `main`, and list the PRs it depends on in the description. The lead rebases it as dependencies land, and the user merges into `main`.
6. **Deploy-safe PRs.**
   - Main deploys automatically. New code goes behind `WEAPON_SKILL_BUILD` or in the `WeaponSkills::` namespace.
   - Schema changes are additive.
   - Stack PRs only inside your workstream.
7. **Owned files only.** Your brief lists them. Anything else is a question on the tracking issue.
8. **Migration timestamps:** `20261016` plus your workstream's hour block: W0 `09xxxx`, W1 `10xxxx`, W2 `11xxxx`, W3 `12xxxx`, W4 `13xxxx`, W5 `14xxxx`, W6 `15xxxx` (W6c uses `1550xx`), W7 `16xxxx`. For example, W3's first migration is `20261016120001`. Every block sorts after the migrations already on `main`. For `db/schema.rb` and `db/data_schema.rb` conflicts, keep the higher version.
9. **Before every PR:**
   - `DATABASE_URL=postgres://localhost/hensei_pipeline_w<n>_test bundle exec rspec` (the full suite, against **your test database**. The test environment reads `DATABASE_URL`, so running rspec with the catalogue database exported would wipe it. A single file fails the coverage minimum, which is expected);
   - `bundle exec rubocop` on changed files;
   - `bin/rails granblue:skill_parity`. It must pass, or the PR refreshes the baseline and explains every change.
   - Curation changes also need `bin/rails granblue:weapon_skill_curation_drift`.
10. **Never parse against the live wiki.** Only W3's fetch task talks to gbf.wiki. Every parse, reparse, extraction and experiment reads stored sources. If a source is missing, ask W3; don't fetch it ad hoc.
11. **Commits and PRs:**
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
| W6a | Structure compiler | W3 | [briefs/W6a.md](briefs/W6a.md) |
| W6b | Row compiler | W0, W3 | [briefs/W6b.md](briefs/W6b.md) |
| W6c | Per-version descriptions | W3 | [briefs/W6c.md](briefs/W6c.md) |
| W7 | Overlay v2 applier | W0, W2 | [briefs/W7.md](briefs/W7.md) |
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
- **Character skills** have the same switch: `CHARACTER_SKILL_BUILD` = `off` | `shadow` | `write` (read in `CharacterSkills.build_mode`, `lib/character_skills.rb`).
  - The deploy hook (`db:migrate:with_data`) runs the weapon build, then the character build (`CharacterSkills::Build::Runner.deploy`), each in its own flag's mode. `shadow` only reports and never fails a deploy; `write` rebuilds the characters whose fingerprint changed.
  - Saving a character whose skill sources change queues `CharacterSkills::BuildJob`. It writes in `write`, or when the character has no skills yet; otherwise it builds in shadow and logs what would change.
  - By hand: `bin/rails granblue:build_character_skills mode=shadow|write [all=true] [ids=GRANBLUE_ID,...] [icons=false]`.
  - Drift check: `bin/rails granblue:character_skill_drift` builds every character in shadow mode and exits nonzero if any built skills differ from the stored ones.

## Character skills backfill (PR 4 runbook)

The data runs from `docs/prds/character-skills-pr4-backfill.md` (workspace repo). Each run happens on a local copy first; production only after the user approves the coverage report and the shadow diff. Never point a local `DATABASE_URL` at production.

- **Fetches don't build per row.** `fetch_wiki_data`, `download_jp_wiki` and `fetch_game_data` write inside `Character.without_skill_build`, print a summary (fetched = unchanged + changed, skipped with reasons, errors) and the changed granblue_ids, then print the build command to run next. `build=shadow|write` runs that build over the changed characters instead; `changed_out=PATH` writes the list, one id per line.
- **Wiki requests** are at least 2s apart (`Granblue::WikiThrottle`; `delay=`/`throttle=` can only raise it).
- **Game requests** (`fetch_game_data`) are at least 2s apart too (`delay=` can only raise it). The run stops at the first authentication failure (expired cookies) and prints the ids it didn't get to; refresh the cookies and resume with that `ids=`.
- **On a local copy**, pass `icons=false` to `build_character_skills mode=write`: a write queues `IconDownloadJob` into whatever Redis the process sees (`build=write` on the fetch tasks always queues it).
- **Coverage** is read-only. Run it before and after every step: `bin/rails granblue:character_skill_coverage [ids=…] [format=csv out=PATH] [s3=true]`. `s3=true` makes one HEAD request per stored icon stem.

Runs, in order:

1. **Before.** `bin/rails granblue:character_skill_coverage format=csv out=tmp/coverage-before.csv`
2. **Run 1, the characters without skills.** Nothing to fetch; the first `write` deploy builds them (no fingerprint). Check `Released, no skills`, then the icons: `bin/rails granblue:download_ability_icons`.
3. **Run 2, refresh wikitext.**
   - `bin/rails granblue:fetch_wiki_data rarity=3 force=true changed_out=tmp/wiki-ssr-changed.txt` (every SSR row, style rows included; about 23 minutes at 2s)
   - `bin/rails granblue:fetch_wiki_data rarity=1,2 changed_out=tmp/wiki-rsr-changed.txt` (R and SR: only rows without `wiki_raw`)
   - `bin/rails granblue:build_character_skills mode=shadow` (every character whose sources changed), review with the user
   - `bin/rails granblue:build_character_skills mode=write`
   - Coverage again: `Blank wiki_raw` should be 0 apart from rows without `wiki_en`; `Ability icons from the wiki stem only` lists the renamed abilities that lost their snapshot icon.
4. **Run 3, game data** (needs the user's game session; see `granblue:fetch_game_data`'s description for the cookies).
   - `awk -F, '$1=="no_game_raw_en"{print $2}' tmp/coverage-before.csv | sort -u > tmp/no-game-raw-en.txt`
   - `bin/rails granblue:fetch_game_data ids=$(paste -sd, tmp/no-game-raw-en.txt) changed_out=tmp/game-changed.txt` (the ids from the coverage CSV's `no_game_raw_en` rows; style 2 is fetched where it's open)
   - `bin/rails granblue:build_character_skills mode=shadow`: expect only icon changes on versions that had none or a wiki stem, and new action ids. Review, then `mode=write`.
5. **Run 4, Japanese text.**
   - `bin/rails granblue:fetch_game_data lang=jp` with the game account set to Japanese, if possible.
   - `bin/rails granblue:download_jp_wiki missing=true changed_out=tmp/jp-changed.txt`
   - `bin/rails granblue:build_character_skills mode=shadow`, review, `mode=write`.
   - `bin/rails granblue:character_skill_coverage format=csv out=tmp/coverage-jp.csv`: the `versions_no_name_jp` rows go to the user.
6. **Run 5, icons in the bucket.**
   - `bin/rails granblue:character_skill_coverage s3=true format=csv out=tmp/coverage-bucket.csv`
   - `bin/rails granblue:download_ability_icons`, then the coverage again; stems still missing go to the user.
