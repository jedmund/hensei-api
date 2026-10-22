# frozen_string_literal: true

# Drops the characters source columns (D35): their data lives in `sources` since the copy
# (data migration 20261020210000) and the sync (20261021180000).
#
# Guard first, in this migration so nothing can order it after the drop: when any column
# still holds a value, both the copy and the sync must be recorded (ar_internal_metadata),
# the sync after the copy, and every value must already be in `sources` — the same rule
# the sync used (missing, or different and not rewritten through the store since the copy).
# Otherwise it raises and the deploy stops with nothing dropped. Logs counts only.
#
# Down re-adds the columns, empty: the data isn't restored (it's in `sources`).
class DropCharacterSourceColumns < ActiveRecord::Migration[8.1]
  class UnsyncedSources < StandardError; end

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
    guard!
    remove_column :characters, :wiki_raw
    remove_column :characters, :wiki_raw_jp
    remove_column :characters, :game_raw_en
    remove_column :characters, :game_raw_jp
    remove_column :characters, :wiki_raw_fetched_at
    remove_column :characters, :wiki_raw_jp_fetched_at
  end

  def down
    add_column :characters, :wiki_raw, :text
    add_column :characters, :game_raw_en, :jsonb, comment: 'JSON data from game (English)'
    add_column :characters, :game_raw_jp, :jsonb, comment: 'JSON data from game (Japanese)'
    add_column :characters, :wiki_raw_jp, :text, comment: 'Raw HTML from gbf-wiki.com (Japanese)'
    add_column :characters, :wiki_raw_fetched_at, :datetime
    add_column :characters, :wiki_raw_jp_fetched_at, :datetime
  end

  private

  def guard!
    with_data = KINDS.values.map(&:first).select { |column| column_has_data?(column) }
    return say('characters source columns are empty; nothing to check') if with_data.empty?

    copied_at = metadata_time(COPIED_AT_KEY)
    synced_at = metadata_time(SYNCED_AT_KEY)
    unless copied_at && synced_at && synced_at > copied_at
      raise UnsyncedSources, 'characters source columns hold data but the copy and a later sync are not both ' \
                             "recorded (#{COPIED_AT_KEY}, #{SYNCED_AT_KEY}); run the sync from the previous release first"
    end

    unsynced = KINDS.sum { |kind, (column, _)| check_kind(kind, column, copied_at) }
    return say('every characters source column value is in sources') if unsynced.zero?

    raise UnsyncedSources, "#{unsynced} characters source column values aren't in sources; " \
                           'run the sync from the previous release first'
  end

  def column_has_data?(column)
    connection.select_value("SELECT EXISTS (SELECT 1 FROM characters WHERE #{column} IS NOT NULL)")
  end

  def metadata_time(key)
    value = connection.select_value("SELECT value FROM ar_internal_metadata WHERE key = #{connection.quote(key)}")
    value && Time.iso8601(value.split.first)
  end

  # → how many values of this kind the sync would still store.
  def check_kind(kind, column, copied_at)
    counts = Hash.new(0)
    each_batch(column) do |rows|
      stored = Source.where(owner_type: 'Character', owner_id: rows.map(&:first), kind: kind, key: '')
                     .pluck(:owner_id, :sha256, :updated_at).to_h { |id, sha, updated_at| [id, [sha, updated_at]] }
      rows.each { |id, value| counts[state(kind, value, stored[id], copied_at)] += 1 }
    end
    say "#{kind}: #{counts.sort.map { |state, n| "#{n} #{state}" }.join(', ').presence || 'nothing'}"
    counts[:missing] + counts[:changed]
  end

  def state(kind, value, stored, copied_at)
    body = body_for(kind, value)
    return :blank if body.nil?

    sha, updated_at = stored
    return :missing unless sha
    return :same if sha == Source.digest(body)

    updated_at > copied_at ? :newer : :changed
  end

  # As the copy and the sync stored a column value.
  def body_for(kind, value)
    value = Granblue::JpWikiPage.trim(value) if kind == 'wiki_raw_jp'
    value = Granblue::GamePayload.sanitize(value) if kind.start_with?('game_raw')
    Source.serialize(kind, value)
  end

  def each_batch(column)
    table = Arel::Table.new(:characters)
    last_id = nil
    loop do
      query = table.project(table[:id], table[column]).where(table[column].not_eq(nil))
      query = query.where(table[:id].gt(last_id)) if last_id
      rows = connection.select_all(query.order(table[:id].asc).take(BATCH)).cast_values
      break if rows.empty?

      yield rows
      last_id = rows.last.first
    end
  end
end
