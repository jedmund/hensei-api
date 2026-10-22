# frozen_string_literal: true

module Granblue
  # The old weapon and summon source columns and the weapon_sources table → `sources` (PR 7b),
  # for the deploy window: the copy migrations run before the deploy while the old code still
  # serves, and anything the old code wrote in the meantime (an editor's fetch_wiki, a
  # gamedata import, granblue:fetch_weapon_sources) never reached the store.
  #
  # Compares each column value and weapon_sources row with its `sources` row by sha256, and
  # stores it when:
  #   - the row differs and hasn't been written through the store since the copy (updated_at
  #     <= the copy's time, recorded by the migrations; a newer row is kept), or
  #   - the row is missing and the old side was written after the copy (a page column's fetch
  #     time, a weapon_sources row's updated_at). A row missing for an older value was deleted
  #     by the new code (a page move, a transfer) and stays deleted. Weapons and summons have
  #     no updated_at and game payloads no fetch time, so a missing payload row is filled:
  #     the new code never removes one (an import always stores a payload).
  # For weapon_sources it also carries a later fetch time or page kind over, and removes store
  # rows the old code deleted (copied ones only). A game payload that isn't a JSON object is
  # skipped and counted. Idempotent; counts only; no build jobs (the deploy build finds changed
  # fingerprints). Each run is recorded (SYNCED_AT_KEY), which the drop migration checks.
  #
  # Each part (the columns, weapon_sources) runs only when its copy times belong to this
  # database: both recorded, and no row of that part created before the copy started. A
  # restored database (bin/setup-pipeline-db reruns data migrations over a dump, and
  # ar_internal_metadata isn't in it) fails that test, and the part is skipped rather than
  # overwriting newer rows or removing rows the store wrote.
  #
  #   bin/rails granblue:sync_item_sources
  class ItemSourceSync
    BATCH = 100
    MODELS = { 'weapons' => 'Weapon', 'summons' => 'Summon' }.freeze
    # kind → [column, fetched_at column or nil]
    COLUMNS = {
      'wiki_raw' => %w[wiki_raw wiki_raw_fetched_at],
      'wiki_raw_jp' => %w[wiki_raw_jp wiki_raw_jp_fetched_at],
      'game_raw_en' => ['game_raw_en', nil],
      'game_raw_jp' => ['game_raw_jp', nil]
    }.freeze
    ITEMS_COPIED_AT_KEY = 'item_sources_copied_at'
    ITEMS_COPY_STARTED_AT_KEY = 'item_sources_copy_started_at'
    # A weapon_sources row.
    OldRow = Struct.new(:weapon_id, :kind, :key, :body, :sha256, :fetched_at, :page_kind, :updated_at)
    STORE_COPIED_AT_KEY = 'weapon_sources_copied_at'
    STORE_COPY_STARTED_AT_KEY = 'weapon_sources_copy_started_at'
    SYNCED_AT_KEY = 'item_sources_synced_at'

    Counts = Struct.new(:checked, :same, :missing, :changed, :newer, :blank, :invalid, :gone, :deleted, :removed,
                        keyword_init: true) do
      def self.zero = new(**members.index_with(0))
      def stored = missing + changed + removed
    end

    # The stored body for a column value (nil: nothing to store), as the copy migration stores
    # it: JP pages trimmed, game payloads sanitized, JSON canonical.
    def self.body_for(kind, value)
      value = Granblue::JpWikiPage.trim(value) if kind == 'wiki_raw_jp'
      value = Granblue::GamePayload.sanitize_item(value) if kind.start_with?('game_raw')
      Source.serialize(kind, value)
    end

    # A game payload that isn't a JSON object (a string or an array): not stored.
    def self.invalid?(kind, value)
      kind.start_with?('game_raw') && !value.nil? && !value.is_a?(Hash)
    end

    def self.metadata(key)
      ActiveRecord::Base.connection.select_value(
        ActiveRecord::Base.sanitize_sql(['SELECT value FROM ar_internal_metadata WHERE key = ?', key])
      )
    end

    def self.synced_at
      value = metadata(SYNCED_AT_KEY)
      value && Time.iso8601(value.split.first)
    end

    def initialize(io: $stdout)
      @io = io
      @items_copied_at, @items_skip = copy_time(ITEMS_COPY_STARTED_AT_KEY, ITEMS_COPIED_AT_KEY,
                                                Source.where(owner_type: MODELS.values, key: ''))
      @store_copied_at, @store_skip = copy_time(STORE_COPY_STARTED_AT_KEY, STORE_COPIED_AT_KEY, WeaponSource.all)
    end

    # → { "weapons.wiki_raw" => Counts, …, "weapon_sources" => Counts }; a skipped part has no entries.
    def call
      results = {}
      unless @items_skip
        MODELS.each do |table, owner_type|
          COLUMNS.each do |kind, (column, fetched_column)|
            results["#{table}.#{kind}"] = sync_column(table, owner_type, kind, column, fetched_column)
          end
        end
      end
      results['weapon_sources'] = sync_store if conn.table_exists?(:weapon_sources) && !@store_skip
      record_synced_at(results)
      report(results)
      results
    end

    private

    def conn = ActiveRecord::Base.connection

    def time(key)
      value = self.class.metadata(key)
      value && Time.iso8601(value)
    end

    # → [copied_at, nil] when the copy times belong to these rows, else [nil, why the part is skipped].
    def copy_time(started_key, copied_key, rows)
      started = time(started_key)
      copied = time(copied_key)
      return [nil, 'copy times not recorded'] unless started && copied
      return [nil, 'rows older than the recorded copy (a restored database)'] if rows.exists?(['created_at < ?', started])

      [copied, nil]
    end

    # A row the store wrote since the copy.
    def newer?(updated_at, copied_at) = updated_at > copied_at

    def sync_column(table, owner_type, kind, column, fetched_column)
      counts = Counts.zero
      each_column_batch(table, column, fetched_column) do |rows|
        stored = Source.where(owner_type: owner_type, owner_id: rows.map(&:first), kind: kind, key: '')
                       .pluck(:owner_id, :sha256, :updated_at).to_h { |id, sha, at| [id, [sha, at]] }
        rows.each { |row| sync_value(owner_type, kind, row, stored[row.first], counts, dated: !fetched_column.nil?) }
      end
      counts
    end

    # row: [id, column value, fetched_at]; stored: [sha256, updated_at] of its row, or nil.
    # dated: the column has a fetch time.
    def sync_value(owner_type, kind, row, stored, counts, dated:)
      id, value, fetched_at = row
      counts.checked += 1
      return counts.invalid += 1 if self.class.invalid?(kind, value)

      body = self.class.body_for(kind, value)
      return counts.blank += 1 if body.nil?

      sha, updated_at = stored
      return counts.same += 1 if sha == Source.digest(body)
      return counts.newer += 1 if sha && newer?(updated_at, @items_copied_at)
      return counts.gone += 1 if sha.nil? && dated && !(fetched_at && newer?(fetched_at, @items_copied_at))

      owner = owner_type.constantize.select(:id).find_by(id: id)
      return counts.deleted += 1 unless owner

      sha ? counts.changed += 1 : counts.missing += 1
      Source.put_body(owner, kind, body, fetched_at: fetched_at)
    end

    # [id, value, fetched_at] for rows with a non-null column, BATCH at a time by id.
    def each_column_batch(table, column, fetched_column)
      arel = Arel::Table.new(table)
      fetched = fetched_column ? arel[fetched_column] : Arel.sql('NULL')
      last_id = nil
      loop do
        query = arel.project(arel[:id], arel[column], fetched).where(arel[column].not_eq(nil))
        query = query.where(arel[:id].gt(last_id)) if last_id
        rows = conn.select_all(query.order(arel[:id].asc).take(BATCH)).cast_values
        break if rows.empty?

        yield rows
        last_id = rows.last.first
      end
    end

    def sync_store
      counts = Counts.zero
      seen = Set.new
      each_store_batch do |rows|
        rows.each do |old|
          seen << [old.weapon_id, old.kind, old.key]
          sync_store_row(old, counts)
        end
      end
      remove_deleted(seen, counts)
      counts
    end

    # old: a weapon_sources row (OldRow).
    def sync_store_row(old, counts)
      counts.checked += 1
      row = WeaponSource.find_by(weapon_id: old.weapon_id, kind: old.kind, key: old.key)
      return confirm(row, old, counts) if row&.sha256 == old.sha256
      return counts.newer += 1 if row && newer?(row.updated_at, @store_copied_at)
      return counts.gone += 1 if row.nil? && !newer?(old.updated_at, @store_copied_at)
      return counts.deleted += 1 if old.weapon_id && !Weapon.exists?(old.weapon_id)

      row ? counts.changed += 1 : counts.missing += 1
      row ||= WeaponSource.new(weapon_id: old.weapon_id, kind: old.kind, key: old.key)
      row.update!(body: old.body, fetched_at: old.fetched_at, page_kind: old.page_kind)
    end

    # Same body: carry over a later fetch time, and the page kind unless the store wrote the row since.
    def confirm(row, old, counts)
      counts.same += 1
      changes = {}
      changes[:fetched_at] = old.fetched_at if old.fetched_at > row.fetched_at
      changes[:page_kind] = old.page_kind if old.page_kind != row.page_kind && !newer?(row.updated_at, @store_copied_at)
      row.update_columns(changes) if changes.any?
    end

    # Store rows copied from weapon_sources (not written since) whose old row is gone.
    def remove_deleted(seen, counts)
      WeaponSource.where(updated_at: ..@store_copied_at).pluck(:id, :weapon_id, :kind, :key).each do |id, *identity|
        next if seen.include?(identity)

        WeaponSource.where(id: id).delete_all
        counts.removed += 1
      end
    end

    def each_store_batch
      last_id = nil
      loop do
        rows = conn.select_all(<<~SQL.squish).cast_values
          SELECT id, weapon_id, kind, key, body, sha256, fetched_at, page_kind, updated_at FROM weapon_sources
          #{"WHERE id > #{conn.quote(last_id)}" if last_id} ORDER BY id LIMIT #{BATCH}
        SQL
        break if rows.empty?

        yield rows.map { |row| OldRow.new(*row.drop(1)) }
        last_id = rows.last.first
      end
    end

    def record_synced_at(results)
      skipped = { 'items' => @items_skip, 'weapon_sources' => @store_skip }.compact.keys
      value = "#{Time.current.utc.iso8601(6)} stored=#{results.values.sum(&:stored)}"
      value += " skipped=#{skipped.join(',')}" if skipped.any?
      conn.execute(ActiveRecord::Base.sanitize_sql([<<~SQL.squish, SYNCED_AT_KEY, value]))
        INSERT INTO ar_internal_metadata (key, value, created_at, updated_at) VALUES (?, ?, now(), now())
        ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()
      SQL
    end

    def report(results)
      @io.puts "items: skipped (#{@items_skip})" if @items_skip
      @io.puts "weapon_sources: skipped (#{@store_skip})" if @store_skip
      results.each do |name, c|
        @io.puts "#{name}: #{c.checked} checked, #{c.same} same, #{c.missing} missing → stored, " \
                 "#{c.changed} changed → stored, #{c.newer} kept (newer in the store), " \
                 "#{c.gone} kept deleted, #{c.blank} blank, #{c.invalid} not an object, " \
                 "#{c.deleted} owner deleted, #{c.removed} removed"
      end
    end
  end
end
