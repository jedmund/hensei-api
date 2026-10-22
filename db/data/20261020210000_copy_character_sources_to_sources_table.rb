# frozen_string_literal: true

# Copies characters.wiki_raw, wiki_raw_jp, game_raw_en and game_raw_jp (with their
# fetched_at) into `sources` rows owned by the character (D35). The columns were dropped
# later (20261022090000).
#
#   - Blank text and JSON null / empty payloads get no row.
#   - wiki_raw_jp is trimmed to div#body with Granblue::JpWikiPage.trim, the function the
#     fetch path uses, so a later refetch of an unchanged page compares equal.
#   - Game payloads keep only character data (Granblue::GamePayload.sanitize) and are stored
#     as canonical JSON text (Source.serialize).
#   - Idempotent: a character that already has a row of a kind is skipped for that kind
#     (a newer fetch through the store wins). Batches by id; logs counts only.
#   - Records when it ran (ar_internal_metadata), so the sync (20261021180000) could copy
#     what the old code wrote to the columns in the meantime.
#
# Reads the columns with SQL; a no-op once they're dropped (20261022090000).
class CopyCharacterSourcesToSourcesTable < ActiveRecord::Migration[8.1]
  BATCH = 100
  # kind → [column, fetched_at column or nil]
  KINDS = {
    'wiki_raw' => %w[wiki_raw wiki_raw_fetched_at],
    'wiki_raw_jp' => %w[wiki_raw_jp wiki_raw_jp_fetched_at],
    'game_raw_en' => ['game_raw_en', nil],
    'game_raw_jp' => ['game_raw_jp', nil]
  }.freeze
  # Read by the sync (20261021180000) and the column drop (20261022090000).
  COPIED_AT_KEY = 'character_sources_copied_at'

  def up
    return say('characters source columns are gone; nothing to copy') unless connection.column_exists?(:characters, :wiki_raw)

    KINDS.each do |kind, (column, fetched_column)|
      copied = 0
      skipped = 0
      each_batch(kind, column, fetched_column) do |rows|
        values = rows.filter_map do |id, value, fetched_at|
          body = body_for(kind, value)
          if body.nil?
            skipped += 1
            next
          end

          [id, body, fetched_at]
        end
        insert(kind, values)
        copied += values.size
      end
      say "#{kind}: #{copied} copied, #{skipped} blank"
    end
    record_copied_at
  end

  # The rows can't be told from ones written through the store since, and the columns
  # stay until the follow-up drop, so there's nothing to restore.
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def db = ActiveRecord::Base.connection
  def quote(value) = db.quote(value)

  # Rows not copied yet with a non-null value, BATCH at a time by id.
  def each_batch(kind, column, fetched_column)
    last_id = nil
    loop do
      # cast_values: jsonb as Ruby values, fetched_at as a UTC Time (not a string a zone could shift)
      rows = db.select_all(<<~SQL.squish).cast_values
        SELECT c.id, c.#{column}, #{fetched_column ? "c.#{fetched_column}" : 'NULL'}
        FROM characters c
        WHERE c.#{column} IS NOT NULL
          #{"AND c.id > #{quote(last_id)}" if last_id}
          AND NOT EXISTS (SELECT 1 FROM sources s WHERE s.owner_type = 'Character' AND s.owner_id = c.id
                          AND s.kind = #{quote(kind)} AND s.key = '')
        ORDER BY c.id
        LIMIT #{BATCH}
      SQL
      break if rows.empty?

      yield rows
      last_id = rows.last.first
    end
  end

  # The stored body for a column value (nil: nothing to store): JP pages trimmed as the
  # fetch path trims them, JSON canonical. Kept here so this
  # migration doesn't depend on code a later cleanup removes.
  def body_for(kind, value)
    value = Granblue::JpWikiPage.trim(value) if kind == 'wiki_raw_jp'
    value = Granblue::GamePayload.sanitize(value) if kind.start_with?('game_raw')
    Source.serialize(kind, value)
  end

  # The first run's time only: a re-run must not move it past rows the old code changed since.
  def record_copied_at
    db.execute(<<~SQL.squish)
      INSERT INTO ar_internal_metadata (key, value, created_at, updated_at)
      VALUES (#{quote(COPIED_AT_KEY)}, #{quote(Time.current.utc.iso8601(6))}, now(), now())
      ON CONFLICT (key) DO NOTHING
    SQL
  end

  def insert(kind, values)
    return if values.empty?

    now = Time.current
    rows = values.map do |id, body, fetched_at|
      { owner_type: 'Character', owner_id: id, kind: kind, key: '', body: body, sha256: Source.digest(body),
        fetched_at: fetched_at, created_at: now, updated_at: now }
    end
    Source.insert_all!(rows)
  end
end
