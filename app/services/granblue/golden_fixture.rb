# frozen_string_literal: true

module Granblue
  # Self-contained golden parties for CI (spec/fixtures/goldens/<shortcode>.json).
  #
  # A fixture holds a golden party's rows (party and grid) plus every catalogue row the
  # damage calculator reads when it validates that party's panel references. Export
  # finds those rows by recording the SQL the calculator runs, so a fixture follows the
  # calculator instead of a hand-kept table list. CI has no catalogue, so the spec loads
  # each fixture into an otherwise empty set of tables and runs PanelValidator on it.
  #
  # Rows are exported with row_to_json and loaded with json_populate_recordset, so values
  # round-trip without passing through the models. Timestamps, user data and free text are
  # left out (see the *_DROP lists); a spec asserts none of PRIVATE_KEYS appear.
  class GoldenFixture
    FORMAT = 1
    DIR = Rails.root.join('spec/fixtures/goldens')

    PARTY_TABLES = %w[parties grid_weapons grid_summons grid_characters].freeze
    # Small reference tables, carried whole so a fixture never depends on which of their
    # rows a pluck happened to read.
    WHOLE_TABLES = %w[weapon_skill_boost_types weapon_skill_families panel_lines weapon_stat_modifiers].freeze
    # Catalogue rows a party row points at (job, accessory, subskills, grid items).
    PARTY_REFERENCES = {
      'parties' => { 'job_id' => 'jobs', 'accessory_id' => 'job_accessories', 'skill0_id' => 'job_skills',
                     'skill1_id' => 'job_skills', 'skill2_id' => 'job_skills', 'skill3_id' => 'job_skills' },
      'grid_weapons' => { 'weapon_id' => 'weapons', 'awakening_id' => 'awakenings', 'weapon_key1_id' => 'weapon_keys',
                          'weapon_key2_id' => 'weapon_keys', 'weapon_key3_id' => 'weapon_keys',
                          'weapon_key4_id' => 'weapon_keys', 'ax_modifier1_id' => 'weapon_stat_modifiers',
                          'ax_modifier2_id' => 'weapon_stat_modifiers', 'befoulment_modifier_id' => 'weapon_stat_modifiers' },
      'grid_summons' => { 'summon_id' => 'summons' },
      'grid_characters' => { 'character_id' => 'characters', 'awakening_id' => 'awakenings' }
    }.freeze

    PRIVATE_KEYS = %w[user_id username email edit_key local_id collection_source_user_id password_digest
                      description video_url].freeze
    PARTY_DROP = (PRIVATE_KEYS + %w[source_party_id raid_id difficulty_id difficulty_score difficulty_breakdown
                                    difficulty_computed_at difficulty_ruleset_version guidebook1_id guidebook2_id
                                    guidebook3_id last_updated collection_weapon_id collection_summon_id
                                    collection_character_id]).freeze
    # Raw page sources and their fetch metadata (game_raw_*, wiki_raw*, e.g.
    # wiki_raw_jp_fetched_at): bulky or volatile, and the calculator never reads them.
    CATALOGUE_DROP = /\A(?:game_raw|wiki_raw)/
    TIMESTAMPS = %w[created_at updated_at].freeze

    # Local edits a reference's notes call for, applied after granblue:import_golden_party
    # and recorded in the fixture's metadata. Imports carry no weapon level, so a grid
    # captured below level 200 is expressed as a lower uncap.
    ADJUSTMENTS = {
      'P8fDVY' => [{ 'table' => 'grid_weapons', 'position' => 4, 'set' => { 'uncap_level' => 4 },
                     'why' => 'Advocatus Diaboli was below level 200 at capture (SL15, ATK-only ' \
                              "Phantom's Supremacy); 4* expresses that, see the reference notes" }]
    }.freeze

    class Error < StandardError; end

    class << self
      def path(shortcode)
        DIR.join("#{shortcode}.json")
      end

      def shortcodes
        DIR.glob('*.json').map { |f| f.basename('.json').to_s }.sort
      end

      # Panel references (parsed) whose party is this shortcode, keyed by reference name.
      def references_for(shortcode)
        Rails.root.glob('data/panel_references/*.json').sort.each_with_object({}) do |file, refs|
          ref = JSON.parse(File.read(file))
          refs[file.basename('.json').to_s] = ref if ref['party'] == shortcode
        end
      end

      def apply_adjustments(party)
        ADJUSTMENTS.fetch(party.shortcode, []).each do |adj|
          raise Error, "unsupported adjustment table #{adj['table']}" unless adj['table'] == 'grid_weapons'

          party.weapons.find_by!(position: adj['position']).update_columns(adj['set'])
        end
      end

      def export(shortcode)
        Exporter.new(shortcode).call
      end

      def write(shortcode)
        fixture = export(shortcode)
        File.write(path(shortcode), dump(fixture))
        fixture
      end

      def read(shortcode)
        JSON.parse(File.read(path(shortcode)))
      end

      # mode:
      #   :replace  - empty every table the fixture carries, then load all of it (tests).
      #   :party    - load only the party and grid rows; the catalogue must already hold
      #               every row they point at (a pipeline or dev database).
      #   :missing  - :party, plus the fixture's catalogue rows this database lacks.
      # Returns the loaded Party.
      def load(fixture, mode: :party)
        fixture = read(fixture) if fixture.is_a?(String)
        Loader.new(fixture, mode).call
      end

      # One row per line, tables in name order, so re-exports diff cleanly.
      def dump(fixture)
        meta = fixture.except('tables').map { |k, v| "  #{k.to_json}: #{v.to_json}" }
        tables = fixture['tables'].sort.map do |table, rows|
          body = rows.map { |r| "      #{r.to_json}" }.join(",\n")
          rows.empty? ? "    #{table.to_json}: []" : "    #{table.to_json}: [\n#{body}\n    ]"
        end
        "{\n#{meta.join(",\n")},\n  \"tables\": {\n#{tables.join(",\n")}\n  }\n}\n"
      end

      def connection
        ActiveRecord::Base.connection
      end
    end

    # Records every SELECT the calculator runs for the party's references, re-runs each one
    # for ids, and embeds those rows.
    class Exporter
      SELECT_HEAD = /\A\s*SELECT\s+(?:DISTINCT\s+)?.+?\s+FROM\s+"(\w+)"/m
      IGNORED_TABLES = %w[ar_internal_metadata schema_migrations data_migrations].freeze

      def initialize(shortcode)
        @shortcode = shortcode
        @references = GoldenFixture.references_for(shortcode)
      end

      def call
        party = Party.find_by(shortcode: @shortcode) or raise Error, "#{@shortcode}: no such party in this database"
        queries = record_queries { exercise(party) }
        ids = Hash.new { |h, k| h[k] = Set.new }
        queries.each { |sql, binds| collect(ids, sql, binds) }
        PARTY_TABLES.each { |t| ids.delete(t) }

        tables = party_tables(party)
        add_party_references(ids, tables)
        WHOLE_TABLES.each { |t| tables[t] = rows(t, nil) }
        ids.each { |table, set| tables[table] ||= rows(table, set) }

        { 'format' => FORMAT, 'shortcode' => @shortcode, 'catalogue_tag' => catalogue_tag,
          'references' => @references.keys, 'adjustments' => ADJUSTMENTS.fetch(@shortcode, []),
          'tables' => tables.sort.to_h }
      end

      private

      def conn = GoldenFixture.connection

      # Runs exactly what the goldens spec runs: each reference through PanelValidator.
      def exercise(party)
        if @references.empty?
          GridDamage::Calculator.panel(party)
        else
          @references.each_value { |ref| PanelValidator.new(ref, party: party).validate }
        end
      end

      def record_queries(&)
        queries = []
        callback = lambda do |*, payload|
          next if payload[:cached] || payload[:name] == 'SCHEMA'
          next unless payload[:sql].match?(/\A\s*SELECT/i)

          queries << [payload[:sql], payload[:binds]]
        end
        ActiveSupport::Notifications.subscribed(callback, 'sql.active_record', &)
        queries.uniq
      end

      # Rewrites a single-table SELECT to select ids instead. Joins and subqueries would
      # read rows that aren't the result rows, so they fail loudly here rather than
      # export an incomplete fixture.
      def collect(ids, sql, binds)
        match = sql.match(SELECT_HEAD) or raise Error, "unsupported query shape: #{sql}"
        table = match[1]
        return if IGNORED_TABLES.include?(table)
        if sql.match?(/\bJOIN\b|\(\s*SELECT\b|\bGROUP\s+BY\b|\bUNION\b/i)
          raise Error, "unsupported query (join/subquery/group): #{sql}"
        end

        ids[table] # an empty result still marks the table as read
        id_sql = sql.sub(SELECT_HEAD, %(SELECT "#{table}"."id" FROM "#{table}"))
        ids[table].merge(conn.select_values(id_sql, 'GoldenFixture', binds).map(&:to_s))
      end

      def party_tables(party)
        tables = {}
        tables['parties'] = rows('parties', [party.id]).map { |r| sanitize_party(r) }
        PARTY_TABLES.drop(1).each do |t|
          ids = conn.select_values("SELECT id FROM #{t} WHERE party_id = #{conn.quote(party.id)}")
          tables[t] = rows(t, ids).map { |r| r.except(*PARTY_DROP) }
        end
        tables
      end

      def sanitize_party(row)
        row.except(*PARTY_DROP).merge('name' => @shortcode)
      end

      def add_party_references(ids, tables)
        PARTY_REFERENCES.each do |table, columns|
          tables[table].each do |row|
            columns.each do |column, target|
              ids[target] << row[column].to_s if row[column].present?
            end
          end
        end
      end

      # Rows of a table as JSON objects, sorted by id; nil ids = the whole table.
      def rows(table, ids)
        return [] if ids && ids.empty?

        where = ids ? "WHERE t.id::text IN (#{ids.map { |i| conn.quote(i.to_s) }.join(', ')})" : ''
        sql = "SELECT row_to_json(t)::text FROM #{conn.quote_table_name(table)} t #{where} ORDER BY t.id::text COLLATE \"C\""
        generated = conn.columns(table).select(&:virtual?).map(&:name)
        conn.select_values(sql).map { |json| JSON.parse(json).except(*TIMESTAMPS, *generated).reject { |k, _| k.match?(CATALOGUE_DROP) } }
      end

      def catalogue_tag
        conn.select_value("SELECT value FROM ar_internal_metadata WHERE key = 'catalogue_tag'")
      end
    end

    # Writes a fixture's rows with INSERT … SELECT FROM json_populate_recordset, naming the
    # fixture's columns so any column it lacks takes its database default.
    class Loader
      def initialize(fixture, mode)
        raise Error, "unknown mode #{mode.inspect}" unless %i[replace party missing].include?(mode)
        raise Error, "fixture format #{fixture['format']} (expected #{FORMAT})" unless fixture['format'] == FORMAT

        @fixture = fixture
        @mode = mode
        @tables = with_skill_owners(fixture.fetch('tables'))
      end

      def call
        conn.transaction(requires_new: true) do
          @mode == :replace ? replace_all : load_party
        end
        Party.find_by!(shortcode: @fixture.fetch('shortcode'))
      end

      private

      def conn = GoldenFixture.connection

      def catalogue_tables = @tables.keys - PARTY_TABLES

      # Fixtures exported before skills were owned by a character row carry
      # character_skills without character_id. Those skills all belonged to the base row
      # (style_swap: false) for their granblue_id: take its id from the fixture's own
      # characters, then from the database.
      def with_skill_owners(tables)
        skills = tables['character_skills']
        return tables if skills.blank? || skills.all? { |row| row['character_id'].present? }

        owners = base_character_ids(tables, skills.pluck('character_granblue_id').compact.uniq)
        tables.merge('character_skills' => skills.map do |row|
          next row if row['character_id'].present?

          row.merge('character_id' => owners[row['character_granblue_id']])
        end)
      end

      def base_character_ids(tables, granblue_ids)
        from_fixture = tables.fetch('characters', [])
                             .reject { |c| c['style_swap'] }
                             .to_h { |c| [c['granblue_id'], c['id']] }
        missing = granblue_ids - from_fixture.keys
        return from_fixture if missing.empty?

        Character.where(granblue_id: missing, style_swap: false).pluck(:granblue_id, :id).to_h.merge(from_fixture)
      end

      # Foreign keys stay off while the tables are emptied and filled: catalogue rows point
      # at rows outside the fixture (a weapon's recruit, a skill's other users) that the
      # calculator never reads. Needs a superuser, which CI and local Postgres both are.
      def replace_all
        conn.execute('SET LOCAL session_replication_role = replica')
        @tables.each_key { |t| conn.execute("DELETE FROM #{conn.quote_table_name(t)}") }
        @tables.each { |t, rows| insert(t, rows) }
        conn.execute('SET LOCAL session_replication_role = DEFAULT')
      end

      def load_party
        catalogue_tables.each { |t| insert(t, @tables[t], skip_conflicts: true) } if @mode == :missing
        check_references!
        party_ids = @tables['parties'].pluck('id')
        stale = Party.where(shortcode: @fixture['shortcode']).or(Party.where(id: party_ids))
        # Grid rows go first, without callbacks: destroying a grid summon recomputes its party.
        [GridWeapon, GridSummon, GridCharacter].each { |model| model.where(party_id: stale.select(:id)).delete_all }
        stale.destroy_all
        PARTY_TABLES.each { |t| insert(t, @tables[t]) }
      end

      def check_references!
        missing = PARTY_REFERENCES.flat_map do |table, columns|
          @tables.fetch(table, []).flat_map do |row|
            columns.filter_map do |column, target|
              id = row[column]
              next if id.blank? || exists?(target, id)

              "#{table}.#{column} -> #{target} #{id}"
            end
          end
        end
        return if missing.empty?

        raise Error, "#{@fixture['shortcode']}: catalogue rows missing from this database " \
                     "(load with mode: :missing to add them):\n  #{missing.uniq.join("\n  ")}"
      end

      def exists?(table, id)
        conn.select_value("SELECT 1 FROM #{conn.quote_table_name(table)} WHERE id::text = #{conn.quote(id.to_s)}").present?
      end

      def insert(table, rows, skip_conflicts: false)
        return if rows.blank?

        known = conn.columns(table).reject(&:virtual?).map(&:name)
        stamp = Time.current.utc.iso8601(6)
        rows = rows.map { |r| (TIMESTAMPS & known).index_with { stamp }.merge(r) }
        columns = rows.flat_map(&:keys).uniq & known
        list = columns.map { |c| conn.quote_column_name(c) }.join(', ')
        quoted = conn.quote_table_name(table)
        # Not squished: that would fold the non-breaking spaces inside the JSON literal.
        conn.execute("INSERT INTO #{quoted} (#{list}) SELECT #{list} " \
                     "FROM json_populate_recordset(NULL::#{quoted}, #{conn.quote(rows.to_json)})" \
                     "#{' ON CONFLICT DO NOTHING' if skip_conflicts}")
      end
    end
  end
end
