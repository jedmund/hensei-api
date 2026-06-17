# Image bucket reorganization

Status: **proposed** — mapping below must be confirmed before execution, because the
new prefixes are baked into two repos (`hensei-svelte` read path, `hensei-api` write
path) **and** the S3 bucket simultaneously.

## Principles

- The local `static/images/` folder is **git-ignored** — a disposable dev mirror. The
  **S3 bucket is the source of truth.**
- All read URLs are built in `hensei-svelte/src/lib/utils/images.ts` (+ a few strays).
  All writes come from `hensei-api` downloaders/services.
- **`previews/` is NOT touched.** It is managed render output used as `og:image`; those
  URLs are cached by external sites/Discord, so re-keying would break shared links.
- **Game-CDN URLs are NOT touched** (`prd-game-a*.akamaized.net …`). Only our own bucket
  prefixes move.
- Cutover is **copy-first** (additive), so nothing 404s mid-migration and rollback is just
  a code revert. Old prefixes are deleted only after a soak.

## Target structure

```
characters/{main,grid,square,detail}/        # was character-{main,grid,square,detail}
weapons/{main,grid,square,base}/              # was weapon-{main,grid,square,base}; weapon-raw REMOVED (orphan)
summons/{main,grid,square,detail,tall,wide}/  # was summon-{…}
accessories/{square,grid}/                    # was accessory-{square,grid}
artifacts/{square,wide}/                       # was artifact-{square,wide}
bullets/square/                                # was bullet-square
jobs/{icon,portrait,wide,zoom,full}/           # was job-icons, job-portraits, job-wide, job-zoom, jobs
raids/{icon,thumbnail,lobby,background,full}/  # was raid-{icon,thumbnail,lobby,background}, raids; raid-square DROPPED
guidebooks/                                    # unchanged

icons/abilities/        # was ability-icons
icons/job-skills/       # was job-skills
icons/elements/         # was elements
icons/proficiencies/    # was proficiencies
icons/rarity/           # was rarity
icons/awakening/        # was awakening
icons/mastery/          # was mastery
icons/ax-skills/        # was ax              (rename: clarify cryptic "ax")
weapon-keys/            # unchanged (stays top-level)
labels/{element,proficiency,race,gender}/     # unchanged (already grouped)

app/fonts/              # was fonts
app/placeholders/       # was placeholders
app/external/           # was external (site logos)
app/media/              # was media (+ dedupe: drop nested images/media/)
app/marketing/          # was loose root files: about-hero.jpg, about-hero2.jpg,
                        #   background_a.jpg, port-breeze.jpg, relief.png
favicon.png             # stays at root (served as site favicon)

previews/               # UNCHANGED (og:image; externally cached)
profile/                # UNCHANGED
updates/                # UNCHANGED
```

## Decisions (confirmed)

1. **`profile/`** — keep as-is.
2. **`updates/`** — keep as-is.
3. **`raid-square/`** — **drop.** Aspirational; no source for the images. (Single stray file.)
4. **`weapon-raw/`** — **remove entirely.** Duplicate of `weapon-base` (same image); orphan with
   no producer (API) and no consumer (app), so removal is a pure S3 delete — no code changes.
   `weapon-base` is the live one → `weapons/base`.
5. **`weapon-keys/`** — keep top-level (not moved under `icons/`).

## Read-path inventory (hensei-svelte)

| File | What to change |
|---|---|
| `src/lib/utils/images.ts` | The hub. `getImageDirectory`, placeholders, accessory/artifact/bullet/awakening/ax/mastery/elements/labels/guidebook/raid builders → new prefixes. `weapon-keys`, `profile`, `guidebooks` stay top-level. **Do NOT change** `GAME_CDN_BASE`, `RAID_*_CDN`. |
| `src/lib/utils/jobUtils.ts` | `job-icons`, `job-portraits`, `job-wide`, `job-zoom` → `jobs/{icon,portrait,wide,zoom}`. |
| `src/lib/utils/modifiers.ts` | `awakening` → `icons/awakening` (weapon-keys stays top-level — unchanged). |
| `src/lib/components/edra/extensions/entity-mention/mentions/helpers.ts` | `character-square`/`{type}-square` → `characters/square` etc.; `ability-icons` → `icons/abilities`. |
| `src/lib/features/database/weapons/AwakeningModal.svelte` | inline `awakening/` → `icons/awakening/` (or route through `getAwakeningImage`). |
| Tests | `images.test.ts`, `jobUtils.test.ts`, `modifiers.test.ts`, mention `helpers.test.ts`/`normalize.test.ts` — update asserted paths. |

**Strategy:** centralize all bucket dir names in one `BUCKET` map in `images.ts`; route the
strays (jobUtils, modifiers, mentions/helpers, AwakeningModal) through it so the structure
lives in exactly one place going forward.

`renderRegistry.ts`/`renderCache.ts` use the `previews/` prefix — **unchanged.**

## Write-path inventory (hensei-api)

Downloaders/services that upload to bucket prefixes (mirror the read structure):

- `lib/granblue/downloaders/base_downloader.rb` (+ `character_`, `weapon_`, `summon_`,
  `artifact_`, `bullet_`, `job_`, `job_accessory_`, `raid_`, `ability_icon_` downloaders)
- `app/services/{character,weapon,summon,artifact,bullet,raid}_image_download_service.rb`
- `app/services/icon_storage.rb`, `app/services/aws_service.rb`
- `lib/tasks/ability_icons.rake`
- `app/jobs/download_*_images_job.rb`

Game-CDN **source** URLs stay; only the **destination** S3 prefix changes. Update specs.

## Migration script (copy-first)

```bash
#!/usr/bin/env bash
# migrate-image-bucket.sh — copy old prefixes to new (additive, idempotent).
# Run BEFORE deploying the repos. previews/ is intentionally excluded.
set -euo pipefail
BUCKET="s3://YOUR_BUCKET"

# old:new pairs
MAP=(
  "character-main:characters/main" "character-grid:characters/grid"
  "character-square:characters/square" "character-detail:characters/detail"
  "weapon-main:weapons/main" "weapon-grid:weapons/grid" "weapon-square:weapons/square"
  "weapon-base:weapons/base"   # weapon-raw intentionally omitted (removed, not migrated)
  "summon-main:summons/main" "summon-grid:summons/grid" "summon-square:summons/square"
  "summon-detail:summons/detail" "summon-tall:summons/tall" "summon-wide:summons/wide"
  "accessory-square:accessories/square" "accessory-grid:accessories/grid"
  "artifact-square:artifacts/square" "artifact-wide:artifacts/wide"
  "bullet-square:bullets/square"
  "job-icons:jobs/icon" "job-portraits:jobs/portrait" "job-wide:jobs/wide"
  "job-zoom:jobs/zoom" "jobs:jobs/full"
  "raid-thumbnail:raids/thumbnail" "raids:raids/full"
  "ability-icons:icons/abilities" "job-skills:icons/job-skills"
  "elements:icons/elements" "proficiencies:icons/proficiencies" "rarity:icons/rarity"
  "awakening:icons/awakening" "mastery:icons/mastery" "ax:icons/ax-skills"
  "fonts:app/fonts" "placeholders:app/placeholders" "external:app/external" "media:app/media"
)
# Unchanged (NOT migrated): weapon-keys/ profile/ updates/ guidebooks/ labels/ previews/ favicon.png
for pair in "${MAP[@]}"; do
  old="${pair%%:*}"; new="${pair##*:}"
  echo "==> $old/ -> $new/"
  aws s3 cp "$BUCKET/$old/" "$BUCKET/$new/" --recursive
done
# loose marketing files
for f in about-hero.jpg about-hero2.jpg background_a.jpg port-breeze.jpg relief.png; do
  aws s3 cp "$BUCKET/$f" "$BUCKET/app/marketing/$f"
done
echo "Copy complete. Deploy repos, soak, then run the --delete pass."
```

A second script (post-soak) does `aws s3 rm "$BUCKET/$old/" --recursive` per old prefix.
The same delete pass also removes the orphans that were never migrated:
`weapon-raw/`, `raid-square/`, the duplicate nested `images/media/`, and stray `.DS_Store`.

## Cutover order (zero-downtime)

1. Confirm mapping (this doc).
2. Run copy script → old + new prefixes both exist in S3.
3. Merge + deploy `hensei-api` (downloaders write to new prefixes) and `hensei-svelte`
   (reads from new prefixes). Both old and new work, so order doesn't matter.
4. Soak (e.g. 1–2 weeks); watch for image 404s.
5. Run delete script → remove old prefixes. Also remove the duplicate `media/extension.mp4`
   nested copy and stray `.DS_Store`.
