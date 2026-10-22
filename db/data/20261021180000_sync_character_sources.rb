# frozen_string_literal: true

# Ran once on the deploy after the copy (20261020210000): stores into `sources` anything the
# previous code wrote to the old character columns after the copy — a value with no row, or
# one that differs from a row not rewritten through the store since the copy. Records the
# run (ar_internal_metadata character_sources_synced_at), which the column drop checks.
#
# No build jobs from a pre-deploy migration: a character whose source this stores gets a new
# fingerprint, and the deploy build rebuilds it. Logs counts only. Self-contained (the sync
# class it used is gone), and a no-op once the columns are dropped.
class SyncCharacterSources < ActiveRecord::Migration[8.1]
  BATCH = 100
  # kind → [column, fetched_at column or nil]
  KINDS = {
    'wiki_raw' => %w[wiki_raw wiki_raw_fetched_at],
    'wiki_raw_jp' => %w[wiki_raw_jp wiki_raw_jp_fetched_at],
    'game_raw_en' => ['game_raw_en', nil],
    'game_raw_jp' => ['game_raw_jp', nil]
  }.freeze
  COPIED_AT_KEY = 'character_sources_copied_at'
  SYNCED_AT_KEY = 'character_sources_synced_at'

  def up
    return say('characters source columns are gone; nothing to sync') unless connection.column_exists?(:characters, :wiki_raw)

    copied_at = metadata_time(COPIED_AT_KEY)
    stored = Set.new
    Character.without_skill_build do
      KINDS.each { |kind, (column, fetched_column)| sync_kind(kind, column, fetched_column, copied_at, stored) }
    end
    record_synced_at(stored.size)
    say "characters to rebuild: #{stored.size}"
  end

  def down
    # Nothing to undo: it only copied current column values into the store.
  end

  private

  def metadata_time(key)
    value = connection.select_value("SELECT value FROM ar_internal_metadata WHERE key = #{connection.quote(key)}")
    value && Time.iso8601(value.split.first)
  end

  def record_synced_at(count)
    value = "#{Time.current.utc.iso8601(6)} synced=#{count}"
    connection.execute(<<~SQL.squish)
      INSERT INTO ar_internal_metadata (key, value, created_at, updated_at)
      VALUES (#{connection.quote(SYNCED_AT_KEY)}, #{connection.quote(value)}, now(), now())
      ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()
    SQL
  end

  def sync_kind(kind, column, fetched_column, copied_at, stored)
    counts = Hash.new(0)
    each_batch(column, fetched_column) do |rows|
      rows_by_id = Source.where(owner_type: 'Character', owner_id: rows.map(&:first), kind: kind, key: '')
                         .pluck(:owner_id, :sha256, :updated_at).to_h { |id, sha, updated_at| [id, [sha, updated_at]] }
      rows.each do |id, value, fetched_at|
        state = sync_one(kind, id, value, fetched_at, rows_by_id[id], copied_at)
        counts[state] += 1
        stored << id if %i[missing changed].include?(state)
      end
    end
    say "#{kind}: #{counts.sort.map { |state, n| "#{n} #{state}" }.join(', ').presence || 'nothing'}"
  end

  # → :blank, :same, :newer (kept), :deleted, or :missing / :changed (stored).
  def sync_one(kind, id, value, fetched_at, row, copied_at)
    body = body_for(kind, value)
    return :blank if body.nil?

    sha, updated_at = row
    return :same if sha == Source.digest(body)
    # Without a copy time only missing rows are filled.
    return :newer if sha && !(copied_at && updated_at <= copied_at)

    character = Character.select(:id).find_by(id: id)
    return :deleted unless character

    Source.put_body(character, kind, body, fetched_at: fetched_at, skip_owner_hook: true)
    sha ? :changed : :missing
  end

  # As the copy stored a column value: JP pages trimmed, game payloads sanitized.
  def body_for(kind, value)
    value = Granblue::JpWikiPage.trim(value) if kind == 'wiki_raw_jp'
    value = Granblue::GamePayload.sanitize(value) if kind.start_with?('game_raw')
    Source.serialize(kind, value)
  end

  def each_batch(column, fetched_column)
    table = Arel::Table.new(:characters)
    fetched = fetched_column ? table[fetched_column] : Arel.sql('NULL')
    last_id = nil
    loop do
      query = table.project(table[:id], table[column], fetched).where(table[column].not_eq(nil))
      query = query.where(table[:id].gt(last_id)) if last_id
      rows = connection.select_all(query.order(table[:id].asc).take(BATCH)).cast_values
      break if rows.empty?

      yield rows
      last_id = rows.last.first
    end
  end
end
