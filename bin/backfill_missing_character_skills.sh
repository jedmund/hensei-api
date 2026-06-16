#!/usr/bin/env bash
#
# Backfill playable characters that have no parsed skills: download their wiki
# data (for any missing it) and parse the skill graph. Safe to re-run — wiki
# fetch skips records that already have wiki_raw, and the parse step only
# touches characters that currently have no skills.
#
# Usage: bin/backfill_missing_character_skills.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

find_missing() {
  bin/rails runner '
    ids = Character.where("granblue_id LIKE ?", "304%")
      .where("NOT EXISTS (SELECT 1 FROM character_skills s WHERE s.character_granblue_id = characters.granblue_id)")
      .order(:granblue_id).pluck(:granblue_id)
    puts "MISSING:#{ids.join(",")}"
  ' 2>/dev/null | sed -n 's/^MISSING://p'
}

ids_csv="$(find_missing)"
if [ -z "$ids_csv" ]; then
  echo "No playable characters are missing skills. Nothing to do."
  exit 0
fi

echo "Characters missing skills: $ids_csv"
echo

echo "== Step 1: download wiki data (skips any that already have wiki_raw) =="
IFS=',' read -ra ids <<< "$ids_csv"
for id in "${ids[@]}"; do
  echo "--- fetch_wiki_data id=$id ---"
  bundle exec rake granblue:fetch_wiki_data type=Character id="$id" || echo "  (fetch failed for $id — continuing)"
done
echo

echo "== Step 2: parse skills for characters that have none (missing-only) =="
bundle exec rake granblue:parse_character_skills
echo

echo "== Result =="
remaining="$(find_missing)"
if [ -z "$remaining" ]; then
  echo "All playable characters now have skills."
else
  echo "Still missing (likely no resolvable wiki page or unparseable wiki format): $remaining"
fi
