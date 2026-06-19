#!/usr/bin/env bash
#
# migrate-image-bucket.sh — STEP 1 of the image bucket reorganization.
#
# Copies every old prefix to its new home (additive; old keys stay live so nothing
# 404s mid-migration). Run this BEFORE promoting staging -> main (the deploy that
# serves new-path code). Merging the PRs into staging is safe without it (staging
# isn't deployed). After a prod soak, run migrate-image-bucket-cleanup.sh.
#
# See docs/follow-ups/image-bucket-reorg.md.
#
# Usage:
#   BUCKET=s3://your-bucket bin/migrate-image-bucket.sh           # dry run (prints only)
#   BUCKET=s3://your-bucket APPLY=1 bin/migrate-image-bucket.sh   # actually copy
#
# previews/ profile/ updates/ guidebooks/ labels/ weapon-keys/ favicon.png and all
# editor-uploaded icons (grid_character_roles/, images/difficulties/) are intentionally
# left in place.
set -euo pipefail

BUCKET="${BUCKET:?Set BUCKET, e.g. BUCKET=s3://siero-img}"
APPLY="${APPLY:-0}"

run() {
	if [[ "$APPLY" == "1" ]]; then
		aws s3 "$@"
	else
		echo "DRY-RUN: aws s3 $*"
	fi
}

# old:new prefix pairs (no trailing slash). weapon-raw and raid-square are NOT here —
# they are orphans removed in the cleanup pass, not migrated.
MAP=(
	"character-main:characters/main" "character-grid:characters/grid"
	"character-square:characters/square" "character-detail:characters/detail"
	"weapon-main:weapons/main" "weapon-grid:weapons/grid" "weapon-square:weapons/square"
	"weapon-base:weapons/base"
	"summon-main:summons/main" "summon-grid:summons/grid" "summon-square:summons/square"
	"summon-detail:summons/detail" "summon-tall:summons/tall" "summon-wide:summons/wide"
	"accessory-square:accessories/square" "accessory-grid:accessories/grid"
	"artifact-square:artifacts/square" "artifact-wide:artifacts/wide"
	"bullet-square:bullets/square"
	"job-icons:jobs/icon" "job-portraits:jobs/portrait" "job-wide:jobs/wide"
	"job-zoom:jobs/zoom" "jobs:jobs/full"
	"raid-thumbnail:raids/thumbnail" "raids:raids/full"
	"ability-icons:icons/abilities" "job-skills:icons/job-skills"
	"weapon-skill-icons:icons/weapon-skills"
	"elements:icons/elements" "proficiencies:icons/proficiencies" "rarity:icons/rarity"
	"awakening:icons/awakening" "mastery:icons/mastery" "ax:icons/ax-skills"
	"fonts:app/fonts" "placeholders:app/placeholders" "external:app/external" "media:app/media"
)

for pair in "${MAP[@]}"; do
	old="${pair%%:*}"
	new="${pair##*:}"
	echo "==> $old/ -> $new/"
	run cp "$BUCKET/$old/" "$BUCKET/$new/" --recursive
done

# Loose marketing files at the bucket root.
for f in about-hero.jpg about-hero2.jpg background_a.jpg port-breeze.jpg relief.png; do
	echo "==> $f -> app/marketing/$f"
	run cp "$BUCKET/$f" "$BUCKET/app/marketing/$f"
done

echo
echo "Copy pass complete. Next: deploy both repos, soak, then run migrate-image-bucket-cleanup.sh."
[[ "$APPLY" == "1" ]] || echo "(this was a DRY RUN — re-run with APPLY=1 to copy)"
