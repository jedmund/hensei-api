# frozen_string_literal: true

# Copies the weapon-skill build's stored inputs from weapon_sources into `sources` (D34,
# PR 7b), where WeaponSource now reads them. Each row keeps its kind, key (the page title),
# body, sha256, fetch time and page_kind (its timestamps are the copy's); a row with a weapon is owned by it
# (owner_type Weapon), the rest (family templates, key series pages) are shared. Same
# bodies and digests, so the build's fingerprints don't change. weapon_sources stays, unread,
# until a follow-up migration drops it.
#
# Idempotent: a row whose (owner, kind, key) is already in `sources` is skipped (a newer fetch
# through the store wins). Batches by id in SQL; logs counts only. No callbacks or jobs.
# Records when it started and finished (ar_internal_metadata weapon_sources_copy_started_at,
# weapon_sources_copied_at) for the post-deploy sync (20261022120000).
class CopyWeaponSourcesToSourcesTable < ActiveRecord::Migration[8.1]
  BATCH = 200
  COPIED_AT_KEY = 'weapon_sources_copied_at'
  STARTED_AT_KEY = 'weapon_sources_copy_started_at'

  def up
    return say('weapon_sources is gone; nothing to copy') unless db.table_exists?(:weapon_sources)

    record_time(STARTED_AT_KEY)
    copied = Hash.new(0)
    kept = Hash.new(0)
    last_id = nil
    loop do
      ids = db.select_values(<<~SQL.squish)
        SELECT id FROM weapon_sources #{"WHERE id > #{quote(last_id)}" if last_id} ORDER BY id LIMIT #{BATCH}
      SQL
      break if ids.empty?

      inserted = db.select_values(<<~SQL.squish)
        INSERT INTO sources (kind, key, body, sha256, fetched_at, page_kind, owner_type, owner_id, created_at, updated_at)
        SELECT ws.kind, ws.key, ws.body, ws.sha256, ws.fetched_at, ws.page_kind,
               CASE WHEN ws.weapon_id IS NULL THEN NULL ELSE 'Weapon' END, ws.weapon_id, clock_timestamp(), clock_timestamp()
        FROM weapon_sources ws
        WHERE ws.id IN (#{ids.map { |id| quote(id) }.join(', ')})
          AND NOT EXISTS (SELECT 1 FROM sources s
                          WHERE s.kind = ws.kind AND s.key = ws.key
                            AND s.owner_id IS NOT DISTINCT FROM ws.weapon_id
                            AND (ws.weapon_id IS NOT NULL OR s.owner_type IS NULL))
        RETURNING kind
      SQL
      inserted.tally.each { |kind, n| copied[kind] += n }
      db.select_values("SELECT kind FROM weapon_sources WHERE id IN (#{ids.map { |id| quote(id) }.join(', ')})")
        .tally.each { |kind, n| kept[kind] += n }
      last_id = ids.last
    end
    (kept.keys | copied.keys).sort.each do |kind|
      say "#{kind}: #{copied[kind]} copied, #{kept[kind] - copied[kind]} already in sources"
    end
    record_time(COPIED_AT_KEY)
  end

  # The rows can't be told from ones written through the store since, and weapon_sources
  # stays until the follow-up drop, so there's nothing to restore.
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def db = ActiveRecord::Base.connection
  def quote(value) = db.quote(value)
  # The database's clock (not the transaction's start, nor the app server's): the rows' timestamps
  # and the recorded copy times come from the same clock, which the sync compares.
  def db_time = db.select_all('SELECT clock_timestamp() AS t').cast_values.first

  # The first run's time only: a re-run must not move it past rows the old code changed since.
  def record_time(key)
    db.execute(<<~SQL.squish)
      INSERT INTO ar_internal_metadata (key, value, created_at, updated_at)
      VALUES (#{quote(key)}, #{quote(db_time.utc.iso8601(6))}, now(), now())
      ON CONFLICT (key) DO NOTHING
    SQL
  end
end
