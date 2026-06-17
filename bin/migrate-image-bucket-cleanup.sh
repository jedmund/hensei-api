#!/usr/bin/env bash
#
# migrate-image-bucket-cleanup.sh — FINAL step of the image bucket reorganization.
#
# Deletes the old prefixes (now duplicated under the new structure) plus the orphans
# that were never migrated. Run ONLY after the copy pass + both deploys have soaked
# and you've confirmed no image 404s. This is destructive.
#
# See docs/follow-ups/image-bucket-reorg.md.
#
# Usage:
#   BUCKET=s3://your-bucket bin/migrate-image-bucket-cleanup.sh           # dry run
#   BUCKET=s3://your-bucket APPLY=1 bin/migrate-image-bucket-cleanup.sh   # actually delete
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

# Old prefixes that were copied to new homes in the copy pass. Safe to recursively
# delete because none nests under a new group prefix.
OLD_PREFIXES=(
	character-main character-grid character-square character-detail
	weapon-main weapon-grid weapon-square weapon-base
	summon-main summon-grid summon-square summon-detail summon-tall summon-wide
	accessory-square accessory-grid artifact-square artifact-wide bullet-square
	job-icons job-portraits job-wide job-zoom
	raid-thumbnail
	ability-icons job-skills elements proficiencies rarity awakening mastery ax
	fonts placeholders external media
)

# Orphans never migrated: weapon-raw (dup of weapon-base, unused) and raid-square
# (aspirational, no source). The duplicate nested images/media/ is dropped too.
ORPHAN_PREFIXES=(weapon-raw raid-square images/media)

for p in "${OLD_PREFIXES[@]}" "${ORPHAN_PREFIXES[@]}"; do
	echo "==> rm $p/"
	run rm "$BUCKET/$p/" --recursive
done

# `jobs/` and `raids/` are special: the OLD assets sit directly under the prefix
# (e.g. jobs/100101.jpg), but the NEW structure ALSO nests under them (jobs/full/,
# jobs/icon/, raids/thumbnail/, …). Delete ONLY the old direct children — `--exclude
# "*/*"` keeps anything in a subdirectory — so the migrated content survives.
for p in jobs raids; do
	echo "==> rm $p/ (direct children only; preserving $p/<new-subdirs>/)"
	run rm "$BUCKET/$p/" --recursive --exclude "*/*"
done

# Loose marketing files now live under app/marketing/.
for f in about-hero.jpg about-hero2.jpg background_a.jpg port-breeze.jpg relief.png .DS_Store; do
	echo "==> rm $f"
	run rm "$BUCKET/$f"
done

echo
[[ "$APPLY" == "1" ]] || echo "(this was a DRY RUN — re-run with APPLY=1 to delete)"
