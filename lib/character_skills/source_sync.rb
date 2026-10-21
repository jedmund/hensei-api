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
  # Idempotent. The stores themselves queue nothing; afterwards one CharacterSkills::BuildJob
  # is queued per character whose source it stored (enqueue_builds: false leaves them to the
  # deploy build, which finds them by fingerprint). Each completed run is recorded in
  # ar_internal_metadata (SYNCED_AT_KEY), which the column-drop migration checks.
  class SourceSync
    BATCH = 100
    # kind → [column, fetched_at column or nil]
    COLUMNS = {
      "wiki_raw" => %w[wiki_raw wiki_raw_fetched_at],
      "wiki_raw_jp" => %w[wiki_raw_jp wiki_raw_jp_fetched_at],
      "game_raw_en" => ["game_raw_en", nil],
      "game_raw_jp" => ["game_raw_jp", nil]
    }.freeze
    # ar_internal_metadata key holding when the copy migration ran (it writes it).
    COPIED_AT_KEY = "character_sources_copied_at"
    # When a sync last completed, and what it stored ("<iso8601> synced=<n>").
    SYNCED_AT_KEY = "character_sources_synced_at"

    # The stored body for a column value (nil: nothing to store), as the copy migration
    # stores it: JP pages trimmed, game payloads sanitized, JSON canonical.
    def self.body_for(kind, value)
      value = Granblue::JpWikiPage.trim(value) if kind == "wiki_raw_jp"
      value = Granblue::GamePayload.sanitize(value) if kind.start_with?("game_raw")
      Source.serialize(kind, value)
    end

    def self.copied_at
      value = ActiveRecord::Base.connection.select_value(
        "SELECT value FROM ar_internal_metadata WHERE key = '#{COPIED_AT_KEY}'"
      )
      value && Time.iso8601(value)
    end

    Counts = Struct.new(:checked, :same, :missing, :changed, :newer, :blank, :deleted, keyword_init: true) do
      def synced = missing + changed
    end

    # Character ids whose sources this run stored (each got one build queued).
    attr_reader :synced_ids

    def self.synced_at
      value = ActiveRecord::Base.connection.select_value(
        "SELECT value FROM ar_internal_metadata WHERE key = '#{SYNCED_AT_KEY}'"
      )
      value && Time.iso8601(value.split.first)
    end

    def initialize(io: $stdout, enqueue_builds: true)
      @io = io
      @enqueue_builds = enqueue_builds
      @copied_at = self.class.copied_at
      @synced_ids = Set.new
    end

    # → { kind => Counts }
    def call
      results = Character.without_skill_build do
        COLUMNS.to_h { |kind, (column, fetched_column)| [kind, sync_kind(kind, column, fetched_column)] }
      end
      @synced_ids.each { |id| CharacterSkills::BuildJob.perform_later(id) } if @enqueue_builds
      record_synced_at
      @io.puts "copy time: #{@copied_at&.iso8601 || 'unknown (only missing rows are filled)'}"
      results.each do |kind, c|
        @io.puts "#{kind}: #{c.checked} checked, #{c.same} same, #{c.missing} missing → stored, " \
                 "#{c.changed} changed → stored, #{c.newer} kept (newer in the store), #{c.blank} blank, " \
                 "#{c.deleted} deleted"
      end
      @io.puts @enqueue_builds ? "skill builds queued: #{@synced_ids.size}" : "characters to rebuild: #{@synced_ids.size}"
      results
    end

    private

    def record_synced_at
      conn = ActiveRecord::Base.connection
      value = "#{Time.current.utc.iso8601(6)} synced=#{@synced_ids.size}"
      conn.execute(<<~SQL.squish)
        INSERT INTO ar_internal_metadata (key, value, created_at, updated_at)
        VALUES ('#{SYNCED_AT_KEY}', #{conn.quote(value)}, now(), now())
        ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()
      SQL
    end

    def sync_kind(kind, column, fetched_column)
      counts = Counts.new(checked: 0, same: 0, missing: 0, changed: 0, newer: 0, blank: 0, deleted: 0)
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

      return counts.newer += 1 if sha && !(@copied_at && updated_at <= @copied_at)

      # Deleted since the batch was read: nothing to store it on.
      character = Character.select(:id).find_by(id: id)
      return counts.deleted += 1 unless character

      sha ? counts.changed += 1 : counts.missing += 1
      Source.put_body(character, kind, body, fetched_at: fetched_at, skip_owner_hook: true)
      @synced_ids << id
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
