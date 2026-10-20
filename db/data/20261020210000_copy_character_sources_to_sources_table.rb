# frozen_string_literal: true

# Copies characters.wiki_raw, wiki_raw_jp, game_raw_en and game_raw_jp (with their
# fetched_at) into `sources` rows owned by the character (D35). The columns stay, unread,
# until a follow-up migration drops them.
#
#   - Blank text and JSON null / empty payloads get no row.
#   - wiki_raw_jp is trimmed to div#body with Granblue::JpWikiPage.trim, the function the
#     fetch path uses, so a later refetch of an unchanged page compares equal.
#   - JSON is stored as canonical text (Source.serialize), so its sha256 is the digest the
#     skill-build fingerprint already used for the jsonb value.
#   - Idempotent: a character that already has a row of a kind is skipped for that kind
#     (a newer fetch through the store wins). Batches by id; logs counts only.
#   - Records when it ran (ar_internal_metadata), so rake granblue:sync_character_sources
#     can copy, after the deploy, what the old code wrote to the columns in the meantime.
#
# Reads the columns with SQL: Character ignores them.
class CopyCharacterSourcesToSourcesTable < ActiveRecord::Migration[8.1]
  BATCH = 100
  # kind → [column, fetched_at column or nil]
  KINDS = CharacterSkills::SourceSync::COLUMNS

  def up
    KINDS.each do |kind, (column, fetched_column)|
      copied = 0
      skipped = 0
      each_batch(kind, column, fetched_column) do |rows|
        values = rows.filter_map do |id, value, fetched_at|
          body = CharacterSkills::SourceSync.body_for(kind, value)
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
    CharacterSkills::SourceSync.record_copied_at
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
