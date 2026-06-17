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
weapons/{main,grid,square,base,raw}/          # was weapon-{main,grid,square,base,raw}
summons/{main,grid,square,detail,tall,wide}/  # was summon-{…}
accessories/{square,grid}/                    # was accessory-{square,grid}
artifacts/{square,wide}/                       # was artifact-{square,wide}
bullets/square/                                # was bullet-square
jobs/{icon,portrait,wide,zoom,full}/           # was job-icons, job-portraits, job-wide, job-zoom, jobs
raids/{icon,thumbnail,lobby,background,full}/  # was raid-{icon,thumbnail,lobby,background}, raids
guidebooks/                                    # unchanged

icons/abilities/        # was ability-icons
icons/job-skills/       # was job-skills
icons/elements/         # was elements
icons/proficiencies/    # was proficiencies
icons/rarity/           # was rarity
icons/awakening/        # was awakening
icons/mastery/          # was mastery
icons/ax-skills/        # was ax              (rename: clarify cryptic "ax")
icons/weapon-keys/      # was weapon-keys
labels/{element,proficiency,race,gender}/     # unchanged (already grouped)

app/fonts/              # was fonts
app/placeholders/       # was placeholders
app/external/           # was external (site logos)
app/media/              # was media (+ dedupe: drop nested images/media/)
app/marketing/          # was loose root files: about-hero.jpg, about-hero2.jpg,
                        #   background_a.jpg, port-breeze.jpg, relief.png
favicon.png             # stays at root (served as site favicon)

previews/               # UNCHANGED (og:image; externally cached)
profile/                # UNCHANGED for now — see open question
updates/                # UNCHANGED for now — see open question
```

## Open questions (confirm before executing)

1. **`profile/`** (84 files) — `getProfileIcon()` builds `profile/{slug}`. Doc-comment says
   "site-brand icons (gamewith/kamigame)" but those live in `external/`, and the dir has 84
   files. Leave as `profile/` (safe) or fold somewhere? **Default: leave.**
2. **`updates/`** (60 files) — changelog images. Move to `app/updates/` or leave? **Default: leave.**
3. **`raid-square/`** (1 file) — looks vestigial; `getRaidImage` builds icon/thumbnail/lobby/
   background, not square. Drop it or map to `raids/square/`? **Default: drop (verify the 1 file).**
4. **`weapon-base` vs `weapon-raw`** — keep both names under `weapons/` (`base`, `raw`) or
   rename for clarity? **Default: keep `base`/`raw`.**
5. **`weapon-keys`** → `icons/weapon-keys` (grouped as an icon set) vs keep top-level. **Default: icons/weapon-keys.**

## Read-path inventory (hensei-svelte)

| File | What to change |
|---|---|
| `src/lib/utils/images.ts` | The hub. `getImageDirectory`, placeholders, accessory/artifact/bullet/awakening/weapon-key/ax/mastery/elements/labels/profile/guidebook/raid builders → new prefixes. **Do NOT change** `GAME_CDN_BASE`, `RAID_*_CDN`. |
| `src/lib/utils/jobUtils.ts` | `job-icons`, `job-portraits`, `job-wide`, `job-zoom` → `jobs/{icon,portrait,wide,zoom}`. |
| `src/lib/utils/modifiers.ts` | `weapon-keys` → `icons/weapon-keys`; `awakening` → `icons/awakening`. |
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
  "weapon-base:weapons/base" "weapon-raw:weapons/raw"
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
  "weapon-keys:icons/weapon-keys"
  "fonts:app/fonts" "placeholders:app/placeholders" "external:app/external" "media:app/media"
)
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

## Cutover order (zero-downtime)

1. Confirm mapping (this doc).
2. Run copy script → old + new prefixes both exist in S3.
3. Merge + deploy `hensei-api` (downloaders write to new prefixes) and `hensei-svelte`
   (reads from new prefixes). Both old and new work, so order doesn't matter.
4. Soak (e.g. 1–2 weeks); watch for image 404s.
5. Run delete script → remove old prefixes. Also remove the duplicate `media/extension.mp4`
   nested copy and stray `.DS_Store`.
```
