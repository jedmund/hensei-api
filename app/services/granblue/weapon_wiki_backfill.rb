# frozen_string_literal: true

module Granblue
  # Fills a weapon's blank gbf.wiki page name (wiki_en) and dates from gbf.wiki's Cargo
  # `weapons` table, matched strictly by game id (granblue_id).
  #
  # Scope: weapons with a blank wiki_en or no release_date (narrowed by ids / rarities).
  # Rows come from one shared Source (kind wiki_cargo, key "weapons") holding every Cargo row
  # fetched so far, by id, plus the ids that were asked for. Only ids not asked for yet are
  # queried (all of them with refresh: true), in chunks of `id IN (...)`, each request after
  # the wiki delay; the stored copy is what gets parsed. offline: true never queries.
  #
  # Fills only blank fields, never overwrites:
  #   wiki_en      ← _pageName
  #   release_date ← release_date
  #   flb_date     ← 4star_date
  #   ulb_date     ← 5star_date
  # The Cargo table has no transcendence date. A date with a precision coarser than a day is
  # reported, not filled. Ids the wiki doesn't have are listed (never guessed by name).
  #
  # Dry run unless write: true; fetched rows are stored either way.
  class WeaponWikiBackfill
    SOURCE_KIND = 'wiki_cargo'
    SOURCE_KEY = 'weapons'
    TABLE = 'weapons'
    # Cargo returns the fields with underscores turned into spaces ("release date").
    FIELDS = '_pageName=page,id,name,rarity,release_date,4star_date,5star_date'
    # Cargo's row limit for anonymous queries; a chunk returning this many is refused.
    LIMIT = 500
    CHUNK_SIZE = 100
    # our column → Cargo result key
    DATE_FIELDS = {
      'release_date' => 'release date',
      'flb_date' => '4star date',
      'ulb_date' => '5star date'
    }.freeze
    # Cargo date precisions that name a full day (0 = date and time, 1 = date).
    DAY_PRECISIONS = ['', '0', '1'].freeze

    class FetchError < StandardError; end

    Change = Struct.new(:weapon, :field, :old, :new, keyword_init: true)
    Note = Struct.new(:weapon, :message, keyword_init: true)
    Result = Struct.new(:scope_count, :changes, :unmatched, :not_fetched, :notes, :requests, :written,
                        keyword_init: true) do
      def changed_weapon_count = changes.map { |change| change.weapon.id }.uniq.size
    end

    # Cargo rows from the stored body: { 'rows' => { id => [row, ...] }, 'queried' => [id, ...] }.
    class Store
      attr_reader :rows, :queried

      def self.load
        value = Source.read(nil, SOURCE_KIND, key: SOURCE_KEY) || {}
        new(value.fetch('rows', {}), value.fetch('queried', []))
      end

      def initialize(rows = {}, queried = [])
        @rows = rows.transform_values { |list| Array(list) }
        @queried = queried.to_set
      end

      def queried?(id) = @queried.include?(id)

      def rows_for(id) = @rows.fetch(id, [])

      # Records a query's answer: every asked id is queried; returned rows replace the stored
      # rows of their id.
      def merge(ids, response_rows)
        @queried.merge(ids)
        ids.each { |id| @rows.delete(id) }
        response_rows.each { |row| (@rows[row['id']] ||= []) << row }
      end

      def save!
        Source.put(nil, SOURCE_KIND, { 'rows' => @rows, 'queried' => @queried.to_a.sort }, key: SOURCE_KEY,
                                                                                          fetched_at: Time.current)
      end
    end

    # The rows of a cargoquery response body. Raises FetchError for an error or a body
    # without results.
    def self.parse_response(body)
      data = JSON.parse(body)
      raise FetchError, "Cargo error: #{data['error'].inspect}" if data['error']
      raise FetchError, 'Cargo response has no cargoquery results' unless data['cargoquery'].is_a?(Array)

      data['cargoquery'].map { |entry| entry.fetch('title') }
    rescue JSON::ParserError => e
      raise FetchError, "Cargo response is not JSON: #{e.message}"
    end

    def self.query_params(ids)
      {
        action: 'cargoquery', tables: TABLE, fields: FIELDS,
        where: "id IN (#{ids.map { |id| %("#{id}") }.join(',')})",
        limit: LIMIT, format: 'json'
      }
    end

    # One live request; the user agent comes from credentials and is never logged.
    DEFAULT_FETCHER = lambda do |ids|
      response = HTTParty.get(Granblue::Parsers::Wiki.base_uri,
                              query: query_params(ids),
                              headers: { 'User-Agent' => Rails.application.credentials.wiki_user_agent })
      raise FetchError, "gbf.wiki returned HTTP #{response.code}" unless response.code == 200

      response.body
    end

    def initialize(ids: nil, rarities: nil, write: false, refresh: false, offline: false, # rubocop:disable Metrics/ParameterLists
                   chunk_size: CHUNK_SIZE, delay: Granblue::WikiThrottle::MIN_DELAY,
                   fetcher: DEFAULT_FETCHER, io: $stdout)
      @ids = ids
      @rarities = rarities
      @write = write
      @refresh = refresh
      @offline = offline
      @chunk_size = chunk_size
      @delay = Granblue::WikiThrottle.clamp(delay)
      @fetcher = fetcher
      @io = io
    end

    def scope
      query = Weapon.where(wiki_en: [nil, '']).or(Weapon.where(release_date: nil))
      query = query.where(granblue_id: @ids) if @ids
      query = query.where(rarity: @rarities) if @rarities
      query.order(:granblue_id)
    end

    def call
      weapons = scope.to_a
      store = Store.load
      wanted = weapons.map(&:granblue_id).compact_blank.uniq
      to_fetch = @refresh ? wanted : wanted.reject { |id| store.queried?(id) }

      requests = 0
      not_fetched = []
      if @offline
        not_fetched = to_fetch
      else
        to_fetch.each_slice(@chunk_size) do |chunk|
          fetch_chunk(store, chunk)
          requests += 1
        end
      end

      result = Result.new(scope_count: weapons.size, changes: [], unmatched: [], not_fetched: not_fetched,
                          notes: [], requests: requests, written: 0)
      weapons.each { |weapon| plan(weapon, store, result) }
      apply(result) if @write
      report(result)
      result
    end

    private

    def fetch_chunk(store, chunk)
      Granblue::WikiThrottle.wait(@delay)
      rows = self.class.parse_response(@fetcher.call(chunk))
      raise FetchError, "Cargo returned #{rows.size} rows for #{chunk.size} ids; use a smaller chunk" if rows.size >= LIMIT

      store.merge(chunk, rows.select { |row| chunk.include?(row['id']) })
      # Saved per chunk, so a later failure keeps what was already fetched.
      store.save!
    end

    def plan(weapon, store, result)
      id = weapon.granblue_id
      return if result.not_fetched.include?(id)

      rows = store.rows_for(id)
      if rows.empty?
        result.unmatched << weapon
        return
      end

      pages = rows.map { |row| row['page'].to_s }.uniq
      if pages.size > 1
        result.notes << Note.new(weapon: weapon, message: "several wiki pages share this id (#{pages.join(', ')}); skipped")
        return
      end

      row = rows.first
      page = Granblue::WikiTitle.normalize(row['page'])
      if weapon.wiki_en.blank? && page.present?
        result.changes << Change.new(weapon: weapon, field: 'wiki_en', old: weapon.wiki_en, new: page)
      end

      DATE_FIELDS.each do |field, key|
        next unless weapon.public_send(field).nil?

        date = cargo_date(row, key, weapon, result)
        result.changes << Change.new(weapon: weapon, field: field, old: nil, new: date) if date
      end
    end

    # A day-precision Cargo date, or nil (blank, partial or invalid ones get a note).
    def cargo_date(row, key, weapon, result)
      value = row[key].to_s.strip
      return if value.empty?

      precision = row["#{key}__precision"].to_s
      unless DAY_PRECISIONS.include?(precision)
        result.notes << Note.new(weapon: weapon, message: "#{key} #{value.inspect} is not a full date (precision #{precision}); skipped")
        return
      end

      Date.iso8601(value[0, 10])
    rescue Date::Error
      result.notes << Note.new(weapon: weapon, message: "#{key} #{value.inspect} is not a date; skipped")
      nil
    end

    def apply(result)
      Weapon.transaction do
        result.changes.group_by(&:weapon).each do |weapon, changes|
          # update_columns: no callbacks, and only the blank fields this run decided on.
          weapon.update_columns(changes.to_h { |change| [change.field, change.new] })
          result.written += 1
        end
      end
    end

    def report(result)
      @io.puts(@write ? 'Writing weapon wiki data:' : 'Dry run (write=true to apply):')
      result.changes.each do |change|
        weapon = change.weapon
        @io.puts "  #{weapon.granblue_id} #{weapon.name_en}: #{change.field}: " \
                 "#{change.old.presence.inspect} → #{change.new.to_s.inspect}"
      end
      result.notes.each { |note| @io.puts "  #{note.weapon.granblue_id} #{note.weapon.name_en}: #{note.message}" }

      @io.puts
      @io.puts "Weapons in scope: #{result.scope_count}"
      @io.puts "Cargo requests: #{result.requests}"
      fields = result.changes.group_by(&:field).transform_values(&:size)
      @io.puts "Proposed changes: #{result.changes.size} on #{result.changed_weapon_count} weapons " \
               "(#{fields.map { |field, count| "#{field} #{count}" }.join(', ').presence || 'none'})"
      @io.puts "Written: #{result.written} weapons" if @write
      list('Not on gbf.wiki Cargo (by id)', result.unmatched)
      return if result.not_fetched.empty?

      @io.puts "Not fetched (offline): #{result.not_fetched.size} ids: #{result.not_fetched.join(', ')}"
    end

    def list(label, weapons)
      @io.puts "#{label}: #{weapons.size}"
      weapons.each { |weapon| @io.puts "  #{weapon.granblue_id} #{weapon.name_en}" }
    end
  end
end
