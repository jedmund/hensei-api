# frozen_string_literal: true

# Copies weapons' and summons' wiki_raw, wiki_raw_jp, game_raw_en and game_raw_jp (with their
# fetched_at) into `sources` rows owned by the item (D35, PR 7b), as
# 20261020210000_copy_character_sources_to_sources_table did for characters. The columns
# stay, unread, until a follow-up migration drops them.
#
#   - Blank text and JSON null / empty payloads get no row; a game payload that isn't a JSON
#     object (a string, an array) gets none either and is counted.
#   - wiki_raw_jp is trimmed to div#body with Granblue::JpWikiPage.trim, the function the
#     fetch path uses, so a later refetch of an unchanged page compares equal.
#   - Game payloads keep only the item's data (Granblue::GamePayload.sanitize_item) and are
#     stored as canonical JSON text (Source.serialize).
#   - Idempotent: an item that already has a row of a kind is skipped for that kind (a newer
#     fetch through the store wins). Batches by id; logs counts only. No callbacks or jobs.
#   - Records when it started and finished (ar_internal_metadata item_sources_copy_started_at,
#     item_sources_copied_at), so the sync after the deploy (Granblue::ItemSourceSync) can copy
#     what the old code wrote to the columns in the meantime, and tell its own rows.
#
# Reads the columns with SQL: Weapon and Summon ignore them.
class CopyItemSourcesToSourcesTable < ActiveRecord::Migration[8.1]
  BATCH = 100
  TABLES = { 'weapons' => 'Weapon', 'summons' => 'Summon' }.freeze
  # kind → [column, fetched_at column or nil]
  KINDS = {
    'wiki_raw' => %w[wiki_raw wiki_raw_fetched_at],
    'wiki_raw_jp' => %w[wiki_raw_jp wiki_raw_jp_fetched_at],
    'game_raw_en' => ['game_raw_en', nil],
    'game_raw_jp' => ['game_raw_jp', nil]
  }.freeze
  COPIED_AT_KEY = 'item_sources_copied_at'
  STARTED_AT_KEY = 'item_sources_copy_started_at'

  def up
    record_time(STARTED_AT_KEY)
    TABLES.each do |table, owner_type|
      KINDS.each do |kind, (column, fetched_column)|
        copied = 0
        skipped = 0
        invalid = 0
        each_batch(table, owner_type, kind, column, fetched_column) do |rows|
          values = rows.filter_map do |id, value, fetched_at|
            if kind.start_with?('game_raw') && !value.is_a?(Hash)
              invalid += 1
              next
            end

            body = body_for(kind, value)
            if body.nil?
              skipped += 1
              next
            end

            [id, body, fetched_at]
          end
          insert(owner_type, kind, values)
          copied += values.size
        end
        say "#{table}.#{kind}: #{copied} copied, #{skipped} blank#{", #{invalid} not an object" if invalid.positive?}"
      end
    end
    record_time(COPIED_AT_KEY)
  end

  # The rows can't be told from ones written through the store since, and the columns stay
  # until the follow-up drop, so there's nothing to restore.
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def db = ActiveRecord::Base.connection
  def quote(value) = db.quote(value)
  # The database's clock (not the transaction's start, nor the app server's): the rows' timestamps
  # and the recorded copy times come from the same clock, which the sync compares.
  def db_time = db.select_all('SELECT clock_timestamp() AS t').cast_values.first

  # Rows not copied yet with a non-null value, BATCH at a time by id.
  def each_batch(table, owner_type, kind, column, fetched_column)
    last_id = nil
    loop do
      # cast_values: jsonb as Ruby values, fetched_at as a UTC Time (not a string a zone could shift)
      rows = db.select_all(<<~SQL.squish).cast_values
        SELECT t.id, t.#{column}, #{fetched_column ? "t.#{fetched_column}" : 'NULL'}
        FROM #{table} t
        WHERE t.#{column} IS NOT NULL
          #{"AND t.id > #{quote(last_id)}" if last_id}
          AND NOT EXISTS (SELECT 1 FROM sources s WHERE s.owner_type = #{quote(owner_type)} AND s.owner_id = t.id
                          AND s.kind = #{quote(kind)} AND s.key = '')
        ORDER BY t.id
        LIMIT #{BATCH}
      SQL
      break if rows.empty?

      yield rows
      last_id = rows.last.first
    end
  end

  # The stored body for a column value (nil: nothing to store): JP pages trimmed as the
  # fetch path trims them, payloads sanitized, JSON canonical. Kept here so this migration
  # doesn't depend on code a later cleanup removes.
  def body_for(kind, value)
    value = Granblue::JpWikiPage.trim(value) if kind == 'wiki_raw_jp'
    value = Granblue::GamePayload.sanitize_item(value) if kind.start_with?('game_raw')
    Source.serialize(kind, value)
  end

  # The first run's time only: a re-run must not move it past rows the old code changed since.
  def record_time(key)
    db.execute(<<~SQL.squish)
      INSERT INTO ar_internal_metadata (key, value, created_at, updated_at)
      VALUES (#{quote(key)}, #{quote(db_time.utc.iso8601(6))}, now(), now())
      ON CONFLICT (key) DO NOTHING
    SQL
  end

  def insert(owner_type, kind, values)
    return if values.empty?

    now = db_time
    rows = values.map do |id, body, fetched_at|
      { owner_type: owner_type, owner_id: id, kind: kind, key: '', body: body, sha256: Source.digest(body),
        fetched_at: fetched_at, created_at: now, updated_at: now }
    end
    Source.insert_all!(rows)
  end
end
