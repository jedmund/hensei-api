# Image bucket reorganization

Status: **executed; cleanup complete (2026-09-27).** The copy pass ran on 2026-06-19, and most old
prefixes have since been deleted. The layout below is the **live** state, verified against
a full listing of `siero-img` (34,884 objects, 2.11 GB) on 2026-09-27. It differs from the
original plan in a few places. Those are called out under
[Differences from the original plan](#differences-from-the-original-plan).

## Principles

- The local `static/images/` folder is **git-ignored**, a disposable dev mirror. The
  **S3 bucket is the source of truth.**
- Read URLs are built in `hensei-svelte/src/lib/utils/images.ts` (the `BUCKET` map, plus
  `jobUtils.ts` and `fonts.ts`) and in hensei-extractor's `src/lib/constants.ts` (a
  `BUCKET` map mirroring the web one). **Keep the two maps in sync.**
- All writes come from `hensei-api` downloaders/services.
- **`previews/` is never touched.** It's render output used as `og:image`; those URLs are
  cached by external sites and Discord, so re-keying would break shared links.
- **Game-CDN URLs are never touched** (`prd-game-a*.akamaized.net …`).
- Changes are **copy-first** (additive): nothing 404s mid-migration, and rollback is a
  code revert. Old prefixes are deleted only after a soak.

## Live structure

```
characters/{main,grid,square,detail}/
weapons/{main,grid,square,base}/
weapons/keys/                                  # NOT top-level weapon-keys/ (see below)
summons/{main,grid,square,detail,tall,wide}/
accessories/{square,grid}/
artifacts/{square,wide}/
bullets/square/
jobs/{icon,portrait,wide,zoom}/                # jobs/full/ exists but is unreferenced
raids/{thumbnail,full}/                        # full/ is kept for use (not yet read; 122 raids vs 134 thumbnails)
guidebooks/

icons/{abilities,job-skills,weapon-skills/{en,ja},skill-labels/{en,ja},
       elements,proficiencies,rarity,awakening,mastery,ax-skills}/
labels/{element,proficiency}/

app/marketing/          # about-hero*.jpg, background_a.jpg, port-breeze.jpg, relief.png
app/placeholders/
app/external/

fonts/                  # NOT moved to app/fonts/ (see below)
images/media/           # NOT moved to app/media/; holds extension.mp4 (see below)
profile/  updates/  previews/  favicon.png     # unchanged
```

There is no `raids/{icon,lobby,background}/` in the bucket, even though
`RaidDownloader` defines those sizes and `getRaidImage()` can build them. See the
`raids/icon/` row below.

## Differences from the original plan

| Plan | Reality | Consequence |
|---|---|---|
| `weapon-keys/` stays top-level | Moved to `weapons/keys/` | Both apps read `weapons/keys/`. `weapon-keys/` no longer exists. |
| `fonts/` → `app/fonts/` | Never moved | hensei-web `getFontBaseUrl()` and the extension's `_fonts.scss` read `fonts/`. Move them first if this ever happens. |
| `media/` → `app/media/` | `images/media/` kept; `app/media/` doesn't exist | hensei-web's `/extension` page reads `images/media/extension.mp4`. The original plan called this a "duplicate" to delete. It isn't. |
| `jobs/` → `jobs/full/` | Copied, but nothing reads it | Web reads `jobs/{icon,portrait,wide,zoom}`. The job downloader writes only `wide` and `zoom`. |
| `raids/` → `raids/full/` | Copied; kept, but nothing reads it yet | Web and extension read only `raids/thumbnail/` from the bucket. `raids/full/` should be used; it covers 122 raids, while thumbnails cover 134. |
| `raids/{icon,lobby,background}/` | Never populated | **Bug:** hensei-web's database raids table (`RaidImageCell`) requests `raids/icon/<slug>.png`, which 404s for every raid. Its game-CDN fallback only runs when a raid has no slug. |

## Leftovers

None. The duplicate folders were deleted on 2026-09-27 (see below).

Kept deliberately:

| Prefix | Objects | Size | Notes |
|---|---|---|---|
| `jobs/full/` | 150 | 21.9 MB | Slug-named job art (`alchemist_a.png`). No reader and no writer, but not a copy of anything (`jobs/zoom/` is ID-named). Kept for now. |

Done on 2026-09-27 (verified by ETag first; versioning is off, so these were permanent):

- Copied `belmervolk-hard.png` and `nihuyvintae-hard.png` (uploaded 2026-09-25, existing only in
  `raids/full/full/`) into `raids/full/`.
- Deleted `raids/full/full/` (254 objects: 120 duplicates of `raids/full/` plus its nested
  `thumbnail/` copy).
- Deleted the 120 loose `raids/*.png` originals (all identical to `raids/full/`).
- Deleted the remaining duplicate folders, 838 objects in total, each verified identical by
  ETag to its kept copy: `raids/full/thumbnail/` (132, recursive copy of `raids/thumbnail/`),
  `weapon-grid/` (385), `weapon-main/` (315) and `weapon-square/` (6), all copies of
  `weapons/*`.

Harmless leftovers: a few zero-byte "folder marker" keys (`guidebooks/`, `images/`, `jobs/`,
`labels/`, `previews/`, `profile/`, `raids/`, `updates/`, `weapons/keys/`, …). No `.DS_Store`
files remain.

## Why the recursion happened

`bin/migrate-image-bucket.sh` mapped `raids:raids/full` and `jobs:jobs/full`, which means
`aws s3 cp raids/ raids/full/ --recursive`. That copies a prefix into its own
subfolder. `raid-thumbnail:raids/thumbnail` runs first in the map, so `raids/thumbnail/` was
swept into `raids/full/thumbnail/`. A second run copied `raids/full/` into itself again,
producing `raids/full/full/` and `raids/full/full/thumbnail/`. The script now copies only
direct children for those two (`--exclude "*/*"`), so re-runs are safe.

The local dev mirror (`hensei-svelte/static/images/`) has the same nesting, which suggests it
was synced from the bucket after the copy pass. `hensei-svelte/scripts/migrate-local-images.sh`
still moves `fonts/` and `media/` locally, which no longer matches the bucket.

## Remaining steps

1. Wire `raids/full/` into hensei-web (with a fallback for raids that have only a thumbnail).
2. Optionally remove the empty folder markers for a clean listing.

The cleanup script has nothing left to do; re-running it is a no-op. It no longer deletes
`fonts/` or `images/media/`, which are still in use.

## Verifying

```bash
# Full inventory → object count and size per folder
aws s3api list-objects-v2 --bucket siero-img \
  --query 'Contents[].[Key,Size,LastModified]' --output text > keys.tsv

# Is a path live? 200 = exists, 403 = missing (the bucket doesn't allow public listing)
curl -s -o /dev/null -w '%{http_code}\n' -I https://siero-img.s3-us-west-2.amazonaws.com/weapons/square/1040007200.jpg
```

## Cutover history

Deploy topology: `staging` is an integration branch and is not deployed; CI/CD deploys from
`main`. Staging and prod read from the same bucket (`siero-img`).

1. Mapping confirmed, both repos' PRs merged into `staging`.
2. Copy pass (`bin/migrate-image-bucket.sh APPLY=1`), 2026-06-19.
3. `staging → main` promoted; the API writes new prefixes and the web reads them.
4. Soak, then the delete pass, which removed most old prefixes. `weapon-grid/`,
   `weapon-main/` and `weapon-square/` survived, and the extension kept the old paths until
   hensei-extractor #93.
