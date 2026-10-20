# frozen_string_literal: true

module CharacterSkills
  # The old characters source columns → their `sources` rows (D35), for the deploy window:
  # the copy migration runs before the deploy while the old code still serves, and a source
  # the old code wrote to a column after the copy never reached the store.
  #
  # rake granblue:sync_character_sources (once, after the deploy is live) compares each
  # column value (read with SQL: Character ignores the columns) with its row by sha256, and
  # re-puts it, with its fetched_at, when:
  #   - the character has no row of that kind, or
  #   - the row differs and hasn't been rewritten since the copy (updated_at <= the copy's
  #     time, recorded by the migration). A row written through the store after the copy is
  #     newer than any column and is kept.
  # Idempotent; no skill builds are queued (the deploy build picks up the new fingerprints).
  class SourceSync
    BATCH = 100
    # kind → [column, fetched_at column or nil]
    COLUMNS = {
      "wiki_raw" => %w[wiki_raw wiki_raw_fetched_at],
      "wiki_raw_jp" => %w[wiki_raw_jp wiki_raw_jp_fetched_at],
      "game_raw_en" => ["game_raw_en", nil],
      "game_raw_jp" => ["game_raw_jp", nil]
    }.freeze
    # ar_internal_metadata key holding when the copy migration ran.
    COPIED_AT_KEY = "character_sources_copied_at"

    # The stored body for a column value (nil: nothing to store). JP pages are trimmed as
    # the fetch path trims them; JSON is canonical (Source.serialize).
    def self.body_for(kind, value)
      value = Granblue::JpWikiPage.trim(value) if kind == "wiki_raw_jp"
      Source.serialize(kind, value)
    end

    def self.copied_at
      value = ActiveRecord::Base.connection.select_value(
        "SELECT value FROM ar_internal_metadata WHERE key = '#{COPIED_AT_KEY}'"
      )
      value && Time.iso8601(value)
    end

    def self.record_copied_at(time = Time.current)
      conn = ActiveRecord::Base.connection
      conn.execute(<<~SQL.squish)
        INSERT INTO ar_internal_metadata (key, value, created_at, updated_at)
        VALUES ('#{COPIED_AT_KEY}', #{conn.quote(time.utc.iso8601(6))}, now(), now())
        ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()
      SQL
    end

    Counts = Struct.new(:checked, :same, :missing, :changed, :newer, :blank, keyword_init: true) do
      def synced = missing + changed
    end

    def initialize(io: $stdout)
      @io = io
      @copied_at = self.class.copied_at
    end

    # → { kind => Counts }
    def call
      results = Character.without_skill_build do
        COLUMNS.to_h { |kind, (column, fetched_column)| [kind, sync_kind(kind, column, fetched_column)] }
      end
      @io.puts "copy time: #{@copied_at&.iso8601 || 'unknown (only missing rows are filled)'}"
      results.each do |kind, c|
        @io.puts "#{kind}: #{c.checked} checked, #{c.same} same, #{c.missing} missing → stored, " \
                 "#{c.changed} changed → stored, #{c.newer} kept (newer in the store), #{c.blank} blank"
      end
      results
    end

    private

    def sync_kind(kind, column, fetched_column)
      counts = Counts.new(checked: 0, same: 0, missing: 0, changed: 0, newer: 0, blank: 0)
      each_batch(column, fetched_column) do |rows|
        stored = Source.where(owner_type: Character.polymorphic_name, owner_id: rows.map(&:first), kind: kind, key: "")
                       .pluck(:owner_id, :sha256, :updated_at).to_h { |id, sha, updated_at| [id, [sha, updated_at]] }
        rows.each { |id, value, fetched_at| sync_one(kind, id, value, fetched_at, stored[id], counts) }
      end
      counts
    end

    def sync_one(kind, id, value, fetched_at, stored, counts)
      counts.checked += 1
      body = self.class.body_for(kind, value)
      return counts.blank += 1 if body.nil?

      sha, updated_at = stored
      return counts.same += 1 if sha == Source.digest(body)

      if sha
        return counts.newer += 1 unless @copied_at && updated_at <= @copied_at

        counts.changed += 1
      else
        counts.missing += 1
      end
      Source.put_body(Character.select(:id).find(id), kind, body, fetched_at: fetched_at, skip_owner_hook: true)
    end

    # [id, value, fetched_at] for characters with a non-null column, BATCH at a time by id.
    def each_batch(column, fetched_column)
      conn = ActiveRecord::Base.connection
      table = Arel::Table.new(:characters)
      fetched = fetched_column ? table[fetched_column] : Arel.sql("NULL")
      last_id = nil
      loop do
        query = table.project(table[:id], table[column], fetched).where(table[column].not_eq(nil))
        query = query.where(table[:id].gt(last_id)) if last_id
        # cast_values: jsonb as Ruby values, fetched_at as a UTC Time
        rows = conn.select_all(query.order(table[:id].asc).take(BATCH)).cast_values
        break if rows.empty?

        yield rows
        last_id = rows.last.first
      end
    end
  end
end
