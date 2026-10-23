# frozen_string_literal: true

# Drops the weapons and summons source columns and the weapon_sources table (PR 7b): their
# data lives in `sources` since the copies (data migrations 20261022110000, 20261022110100)
# and the sync (20261022120000).
#
# Guard first, in this migration so nothing can order it after the drop. When a column or
# weapon_sources still holds data:
#   - the sync must be recorded (ar_internal_metadata item_sources_synced_at), later than both
#     copies, and not marked skipped (a part it skipped was never checked);
#   - a check with the sync's rules must find nothing left to store: no column value or
#     weapon_sources row missing from `sources` or different from a row not rewritten since the
#     copy, and no copied store row whose weapon_sources row is gone.
# Otherwise it raises and the deploy stops with nothing dropped. Logs counts only.
#
# Down re-adds the columns and the table, empty: the data isn't restored (it's in `sources`).
class DropItemSourceColumns < ActiveRecord::Migration[8.1]
  class UnsyncedSources < StandardError; end

  BATCH = 100
  TABLES = { 'weapons' => 'Weapon', 'summons' => 'Summon' }.freeze
  # kind → [column, fetched_at column or nil]
  KINDS = {
    'wiki_raw' => %w[wiki_raw wiki_raw_fetched_at],
    'wiki_raw_jp' => %w[wiki_raw_jp wiki_raw_jp_fetched_at],
    'game_raw_en' => ['game_raw_en', nil],
    'game_raw_jp' => ['game_raw_jp', nil]
  }.freeze
  STORE_KINDS = %w[wiki_raw expanded transclusion family_template].freeze
  ITEMS_COPIED_AT_KEY = 'item_sources_copied_at'
  STORE_COPIED_AT_KEY = 'weapon_sources_copied_at'
  SYNCED_AT_KEY = 'item_sources_synced_at'

  def up
    guard!
    TABLES.each_key do |table|
      KINDS.each_value do |column, fetched_column|
        remove_column table, column if column_exists?(table, column)
        remove_column table, fetched_column if fetched_column && column_exists?(table, fetched_column)
      end
    end
    drop_table :weapon_sources if table_exists?(:weapon_sources)
  end

  def down
    %w[weapons summons].each do |table|
      add_column table, :wiki_raw, :text
      add_column table, :game_raw_en, :jsonb, comment: 'JSON data from game (English)'
      add_column table, :game_raw_jp, :jsonb, comment: 'JSON data from game (Japanese)'
      add_column table, :wiki_raw_jp, :text, comment: 'Raw HTML from gbf-wiki.com (Japanese)'
      add_column table, :wiki_raw_fetched_at, :datetime
      add_column table, :wiki_raw_jp_fetched_at, :datetime
    end
    add_index :weapons, :wiki_raw_fetched_at
    create_weapon_sources
  end

  private

  def guard!
    columns = TABLES.keys.product(KINDS.values.map(&:first)).select { |table, column| data?(table, column) }
    store = table_exists?(:weapon_sources) && select_value('SELECT EXISTS (SELECT 1 FROM weapon_sources)')
    return say('weapons/summons source columns and weapon_sources are empty; nothing to check') if columns.empty? && !store

    items_copied_at, store_copied_at = check_sync_recorded!
    unsynced = columns.sum do |table, column|
      kind, (_, fetched_column) = KINDS.find { |_, (c, _)| c == column }
      check_column(table, TABLES[table], kind, column, fetched_column, items_copied_at)
    end
    unsynced += check_store(store_copied_at) if store
    return say('every weapons/summons source value and weapon_sources row is in sources') if unsynced.zero?

    raise UnsyncedSources, "#{unsynced} weapon/summon source values aren't in sources; run " \
                           'granblue:sync_item_sources from the previous release first'
  end

  # → [items copied_at, weapon_sources copied_at]
  def check_sync_recorded!
    items_copied_at = metadata_time(ITEMS_COPIED_AT_KEY)
    store_copied_at = metadata_time(STORE_COPIED_AT_KEY)
    synced = select_value("SELECT value FROM ar_internal_metadata WHERE key = #{quote(SYNCED_AT_KEY)}")
    synced_at = synced && Time.iso8601(synced.split.first)
    if items_copied_at.nil? || store_copied_at.nil? || synced_at.nil? ||
       synced_at <= [items_copied_at, store_copied_at].max
      raise UnsyncedSources, 'the weapon/summon source copies and a later sync are not all recorded ' \
                             "(#{ITEMS_COPIED_AT_KEY}, #{STORE_COPIED_AT_KEY}, #{SYNCED_AT_KEY}); run the sync first"
    end
    if synced.include?('skipped=')
      raise UnsyncedSources, "the last sync skipped part of its work (#{SYNCED_AT_KEY}: #{synced.split.last}); " \
                             'check the copy times and run it again'
    end
    [items_copied_at, store_copied_at]
  end

  def data?(table, column)
    column_exists?(table, column) && select_value("SELECT EXISTS (SELECT 1 FROM #{table} WHERE #{column} IS NOT NULL)")
  end

  def metadata_time(key)
    value = select_value("SELECT value FROM ar_internal_metadata WHERE key = #{quote(key)}")
    value && Time.iso8601(value.split.first)
  end

  def quote(value) = connection.quote(value)

  # → how many values of this column the sync would still store.
  def check_column(table, owner_type, kind, column, fetched_column, copied_at) # rubocop:disable Metrics/ParameterLists
    counts = Hash.new(0)
    each_column_batch(table, column, fetched_column) do |rows|
      stored = Source.where(owner_type: owner_type, owner_id: rows.map(&:first), kind: kind, key: '')
                     .pluck(:owner_id, :sha256, :updated_at).to_h { |id, sha, updated_at| [id, [sha, updated_at]] }
      rows.each do |id, value, fetched_at|
        counts[column_state(kind, value, fetched_at, stored[id], copied_at, dated: !fetched_column.nil?)] += 1
      end
    end
    say "#{table}.#{kind}: #{format_counts(counts)}"
    counts[:missing] + counts[:changed]
  end

  # The sync's rules (Granblue::ItemSourceSync, PR 7b).
  def column_state(kind, value, fetched_at, stored, copied_at, dated:) # rubocop:disable Metrics/ParameterLists
    return :invalid if kind.start_with?('game_raw') && !value.is_a?(Hash)

    body = body_for(kind, value)
    return :blank if body.nil?

    sha, updated_at = stored
    return :same if sha == Source.digest(body)
    return :newer if sha && updated_at > copied_at
    return :gone if sha.nil? && dated && !(fetched_at && fetched_at > copied_at)

    sha ? :changed : :missing
  end

  # As the copy and the sync stored a column value.
  def body_for(kind, value)
    value = Granblue::JpWikiPage.trim(value) if kind == 'wiki_raw_jp'
    value = Granblue::GamePayload.sanitize_item(value) if kind.start_with?('game_raw')
    Source.serialize(kind, value)
  end

  # → how many weapon_sources rows the sync would still store, plus copied store rows it
  # would remove.
  def check_store(copied_at)
    counts = Hash.new(0)
    seen = Set.new
    each_store_batch do |rows|
      rows.each do |weapon_id, kind, key, sha, updated_at|
        seen << [weapon_id, kind, key]
        counts[store_state(weapon_id, kind, key, sha, updated_at, copied_at)] += 1
      end
    end
    counts[:removable] = removable(seen, copied_at)
    say "weapon_sources: #{format_counts(counts)}"
    counts[:missing] + counts[:changed] + counts[:removable]
  end

  def store_state(weapon_id, kind, key, sha, updated_at, copied_at) # rubocop:disable Metrics/ParameterLists
    row = store_rows.where(owner_id: weapon_id, kind: kind, key: key).pick(:sha256, :updated_at)
    return :same if row && row.first == sha
    return :newer if row && row.last > copied_at
    return :gone if row.nil? && updated_at <= copied_at
    return :deleted if weapon_id && !select_value("SELECT EXISTS (SELECT 1 FROM weapons WHERE id = #{quote(weapon_id)})")

    row ? :changed : :missing
  end

  # Copied store rows (not written since) whose weapon_sources row is gone.
  def removable(seen, copied_at)
    store_rows.where(updated_at: ..copied_at).pluck(:owner_id, :kind, :key).count { |identity| !seen.include?(identity) }
  end

  # The weapon-skill store's rows of `sources` (as WeaponSource scopes them).
  def store_rows
    Source.where(kind: STORE_KINDS, owner_type: [nil, 'Weapon']).where.not(key: '')
  end

  def each_column_batch(table, column, fetched_column)
    arel = Arel::Table.new(table)
    fetched = fetched_column ? arel[fetched_column] : Arel.sql('NULL')
    last_id = nil
    loop do
      query = arel.project(arel[:id], arel[column], fetched).where(arel[column].not_eq(nil))
      query = query.where(arel[:id].gt(last_id)) if last_id
      rows = connection.select_all(query.order(arel[:id].asc).take(BATCH)).cast_values
      break if rows.empty?

      yield rows
      last_id = rows.last.first
    end
  end

  def each_store_batch
    last_id = nil
    loop do
      rows = connection.select_all(<<~SQL.squish).cast_values
        SELECT id, weapon_id, kind, key, sha256, updated_at FROM weapon_sources
        #{"WHERE id > #{quote(last_id)}" if last_id} ORDER BY id LIMIT #{BATCH}
      SQL
      break if rows.empty?

      yield rows.map { |row| row.drop(1) }
      last_id = rows.last.first
    end
  end

  def format_counts(counts)
    counts.reject { |_, n| n.zero? }.sort.map { |state, n| "#{n} #{state}" }.join(', ').presence || 'nothing'
  end

  def create_weapon_sources
    create_table :weapon_sources, id: :uuid do |t|
      t.references :weapon, type: :uuid, foreign_key: { on_delete: :cascade }, null: true, index: false
      t.string :kind, null: false
      t.string :key, null: false
      t.text :body, null: false
      t.string :sha256, null: false
      t.datetime :fetched_at, null: false
      t.string :page_kind
      t.timestamps
    end
    add_index :weapon_sources, %i[weapon_id kind key], unique: true, where: 'weapon_id IS NOT NULL',
                                                       name: 'index_weapon_sources_on_weapon_kind_key'
    add_index :weapon_sources, %i[kind key], unique: true, where: 'weapon_id IS NULL',
                                             name: 'index_weapon_sources_on_shared_kind_key'
    add_index :weapon_sources, %i[kind key fetched_at], name: 'index_weapon_sources_lookup'
    add_check_constraint :weapon_sources, "kind IN ('wiki_raw', 'expanded', 'transclusion', 'family_template')",
                         name: 'weapon_sources_kind'
    add_check_constraint :weapon_sources,
                         "page_kind IS NULL OR page_kind IN ('inline', 'series_template', 'key_determined')",
                         name: 'weapon_sources_page_kind'
  end
end
