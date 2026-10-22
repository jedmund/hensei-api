# frozen_string_literal: true

module Granblue
  # The old weapon and summon source columns and the weapon_sources table → `sources` (PR 7b),
  # for the deploy window: the copy migrations run before the deploy while the old code still
  # serves, and anything the old code wrote in the meantime (an editor's fetch_wiki, a
  # gamedata import, granblue:fetch_weapon_sources) never reached the store.
  #
  # Compares each column value and weapon_sources row with its `sources` row by sha256, and
  # stores it when the row is missing, or differs and hasn't been written through the store
  # since the copy (updated_at <= the copy's time, recorded by the migrations). A row written
  # through the store after the copy is newer and is kept. For weapon_sources it also carries a
  # later fetch time or page kind over, and removes store rows the old code deleted (copied
  # ones only). Idempotent; counts only; no build jobs (the deploy build finds changed
  # fingerprints). Each completed run is recorded (SYNCED_AT_KEY), which the drop migration
  # checks.
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
    # A weapon_sources row.
    OldRow = Struct.new(:weapon_id, :kind, :key, :body, :sha256, :fetched_at, :page_kind)
    STORE_COPIED_AT_KEY = 'weapon_sources_copied_at'
    SYNCED_AT_KEY = 'item_sources_synced_at'

    Counts = Struct.new(:checked, :same, :missing, :changed, :newer, :blank, :deleted, :removed, keyword_init: true) do
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
      @items_copied_at = time(ITEMS_COPIED_AT_KEY)
      @store_copied_at = time(STORE_COPIED_AT_KEY)
    end

    # → { "weapons.wiki_raw" => Counts, …, "weapon_sources" => Counts }
    def call
      results = {}
      MODELS.each do |table, owner_type|
        COLUMNS.each do |kind, (column, fetched_column)|
          results["#{table}.#{kind}"] = sync_column(table, owner_type, kind, column, fetched_column)
        end
      end
      results['weapon_sources'] = sync_store if conn.table_exists?(:weapon_sources)
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

    # A row the store wrote since the copy (or any row, when the copy time is unknown).
    def newer?(updated_at, copied_at) = copied_at.nil? || updated_at > copied_at

    def sync_column(table, owner_type, kind, column, fetched_column)
      counts = Counts.zero
      each_column_batch(table, column, fetched_column) do |rows|
        stored = Source.where(owner_type: owner_type, owner_id: rows.map(&:first), kind: kind, key: '')
                       .pluck(:owner_id, :sha256, :updated_at).to_h { |id, sha, at| [id, [sha, at]] }
        rows.each { |row| sync_value(owner_type, kind, row, stored[row.first], counts) }
      end
      counts
    end

    # row: [id, column value, fetched_at]; stored: [sha256, updated_at] of its row, or nil.
    def sync_value(owner_type, kind, row, stored, counts)
      id, value, fetched_at = row
      counts.checked += 1
      body = self.class.body_for(kind, value)
      return counts.blank += 1 if body.nil?

      sha, updated_at = stored
      return counts.same += 1 if sha == Source.digest(body)
      return counts.newer += 1 if sha && newer?(updated_at, @items_copied_at)

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
      return if @store_copied_at.nil?

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
          SELECT id, weapon_id, kind, key, body, sha256, fetched_at, page_kind FROM weapon_sources
          #{"WHERE id > #{conn.quote(last_id)}" if last_id} ORDER BY id LIMIT #{BATCH}
        SQL
        break if rows.empty?

        yield rows.map { |row| OldRow.new(*row.drop(1)) }
        last_id = rows.last.first
      end
    end

    def record_synced_at(results)
      value = "#{Time.current.utc.iso8601(6)} stored=#{results.values.sum(&:stored)}"
      conn.execute(ActiveRecord::Base.sanitize_sql([<<~SQL.squish, SYNCED_AT_KEY, value]))
        INSERT INTO ar_internal_metadata (key, value, created_at, updated_at) VALUES (?, ?, now(), now())
        ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()
      SQL
    end

    def report(results)
      @io.puts "copy times: items #{@items_copied_at&.iso8601 || 'unknown'}, " \
               "weapon_sources #{@store_copied_at&.iso8601 || 'unknown'} (unknown: only missing rows are filled)"
      results.each do |name, c|
        @io.puts "#{name}: #{c.checked} checked, #{c.same} same, #{c.missing} missing → stored, " \
                 "#{c.changed} changed → stored, #{c.newer} kept (newer in the store), #{c.blank} blank, " \
                 "#{c.deleted} owner deleted, #{c.removed} removed"
      end
    end
  end
end
