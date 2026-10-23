# frozen_string_literal: true

require 'httparty'

# GranblueWiki fetches and parses data from gbf.wiki
module Granblue
  module Parsers
    class Wiki
      class_attribute :base_uri

      class_attribute :proficiencies
      class_attribute :elements
      class_attribute :rarities
      class_attribute :genders
      class_attribute :races
      class_attribute :bullets
      class_attribute :boolean
      class_attribute :character_series
      class_attribute :character_seasons

      self.base_uri = 'https://gbf.wiki/api.php'

      self.proficiencies = {
        'Sabre' => 1,
        'Dagger' => 2,
        'Axe' => 3,
        'Spear' => 4,
        'Bow' => 5,
        'Staff' => 6,
        'Melee' => 7,
        'Harp' => 8,
        'Gun' => 9,
        'Katana' => 10
      }.freeze

      self.elements = {
        'Wind' => 1,
        'Fire' => 2,
        'Water' => 3,
        'Earth' => 4,
        'Dark' => 5,
        'Light' => 6
      }.freeze

      self.rarities = {
        'R' => 1,
        'SR' => 2,
        'SSR' => 3
      }.freeze

      self.races = {
        'Other' => 0,
        'Human' => 1,
        'Erune' => 2,
        'Draph' => 3,
        'Harvin' => 4,
        'Primal' => 5
      }.freeze

      self.genders = {
        'o' => 0,
        'm' => 1,
        'f' => 2,
        'mf' => 3
      }.freeze

      self.bullets = {
        'cartridge' => 1,
        'rifle' => 2,
        'parabellum' => 3,
        'aetherial' => 4
      }.freeze

      self.boolean = {
        'yes' => true,
        'no' => false
      }.freeze

      # Maps wiki |series= values to CHARACTER_SERIES enum values
      # Wiki uses lowercase, single values like "grand", "zodiac", etc.
      self.character_series = {
        'grand' => 1,       # Grand
        'zodiac' => 2,      # Zodiac
        'promo' => 3,       # Promo
        'collab' => 4,      # Collab
        'eternal' => 5,     # Eternal
        'evoker' => 6,      # Evoker
        'archangel' => 7,   # Saint (Archangels)
        'fantasy' => 8,     # Fantasy
        'summer' => 9,      # Summer
        'yukata' => 10,     # Yukata
        'valentine' => 11,  # Valentine
        'halloween' => 12,  # Halloween
        'formal' => 13,     # Formal
        'holiday' => 14,    # Holiday
        'event' => 15       # Event
      }.freeze

      # Maps wiki seasonal indicators to CHARACTER_SEASONS enum values
      # Used for display disambiguation (e.g., "Vane [Halloween]")
      # If no season matches, value should be nil
      self.character_seasons = {
        'valentine' => 1,   # Valentine
        'formal' => 2,      # Formal
        'summer' => 3,      # Summer (includes Yukata)
        'halloween' => 4,   # Halloween
        'holiday' => 5      # Holiday
      }.freeze

      # Pools an ordinary Premium item appears in: every banner but Classic
      # (Flash, Legend, each season and Collab draws all include Premium)
      ORDINARY_PROMOTIONS = [1, 4, 5, 6, 7, 8, 9, 10, 11].freeze

      # Wiki |obtain= tokens for limited pools, and the pool each maps to
      LIMITED_PROMOTIONS = {
        'valentine' => 6,
        'summer' => 7,
        'swimsuit' => 7,
        'halloween' => 8,
        'holiday' => 9,
        'formal' => 11
      }.freeze

      # Maps a wiki |obtain= value (e.g. "premium,gala,flash") to PROMOTIONS
      # enum values, matching how the curated catalogue stores pools:
      # - limited items only appear in their limited pool, never in Premium:
      #   gala,flash is Flash Gala; gala,normal, legend and zodiac are Legend
      #   Festival; a season token is that season's pool
      # - premium,collab is the Collab draw; other collab items are event rewards
      # - premium,normal items appear in every Premium-type banner; other
      #   premium variants (ticket-only, special draw sets) are in no pool
      # - Classic pools are added only when the wiki names them
      # @return [Array<Integer>]
      def self.promotions_from_obtain(obtain)
        tokens = obtain.to_s.downcase.split(/[,;]/).map(&:strip)

        premium = tokens.include?('premium')
        limited = tokens.filter_map { |token| LIMITED_PROMOTIONS[token] }
        limited << 10 if premium && tokens.include?('collab')
        limited << 4 if tokens.include?('flash')
        if tokens.include?('legend') || tokens.include?('zodiac') || (tokens.include?('gala') && !tokens.include?('flash'))
          limited << 5
        end
        return limited.uniq.sort if limited.any?

        return [] if tokens.include?('collab')

        promotions = premium && tokens.include?('normal') ? ORDINARY_PROMOTIONS.dup : []
        promotions << 2 if tokens.include?('classic')
        promotions << 3 if tokens.include?('classic2')
        promotions << 12 if tokens.include?('classic3')
        promotions.uniq.sort
      end

      SOURCE_STORE_KEY = :granblue_wiki_source_store
      # Page kinds a plain fetch(page) may be stored under, in lookup order: pages a parser
      # follows (transclusions, templates), then whole pages (key series pages).
      FETCH_KINDS = %w[transclusion wiki_raw].freeze

      # Runs the block with every Wiki reading from a SourceStore instead of gbf.wiki:
      # fetch, expand and fetch_raw return stored bodies, and a miss raises
      # WeaponSkills::SourceStore::SourceMissing. Scoped to the current thread.
      def self.offline(store: WeaponSkills::SourceStore::Database.new)
        previous = Thread.current[SOURCE_STORE_KEY]
        Thread.current[SOURCE_STORE_KEY] = store
        yield
      ensure
        Thread.current[SOURCE_STORE_KEY] = previous
      end

      # The store reads come from: an explicit offline scope, else the database store
      # whenever the weapon-skill build is on, else none (the network, as before).
      def self.current_store
        Thread.current[SOURCE_STORE_KEY] ||
          (WeaponSkills.build_mode == 'off' ? nil : WeaponSkills::SourceStore::Database.new)
      end

      # store: :ambient follows Wiki.current_store at call time; nil always uses the
      # network (the fetch step itself); a SourceStore always reads from it.
      def initialize(props: ['wikitext'], debug: false, store: :ambient)
        @debug = debug
        @props = props.join('|')
        @store = store
      end

      def store
        @store == :ambient ? self.class.current_store : @store
      end

      # kind: which stored kind to read in store mode (default: transclusion, then wiki_raw).
      def fetch(page, kind: nil)
        page = Granblue::WikiTitle.normalize(page)
        return stored_page(page, kind) if store

        ap "--> Fetching #{page}" if @debug

        # The title goes in as a query parameter, encoded by HTTParty.
        response = WikiHttp.with_timeouts(page) do
          HTTParty.get(base_uri, query: params(page),
                                 headers: { 'User-Agent' => Rails.application.credentials.wiki_user_agent },
                                 **WikiHttp::OPTIONS)
        end

        handle_response(response, page)
      end

      # Expand the templates in a chunk of wikitext (action=expandtemplates) — resolves the
      # {{Weapon/Common/<Series>}} wrapper so series-template skills (Bahamut/Xeno/Militis/…)
      # render their skill rows. Returns the expanded wikitext/HTML, or nil on an error response
      # (a timeout raises WikiError, like the other requests here).
      # page: the weapon page the text came from, which keys the stored expansion.
      def expand(text, page: nil)
        return stored_expansion(text, page) if store

        response = WikiHttp.with_timeouts(page) do
          HTTParty.post(base_uri,
                        body: { action: 'expandtemplates', format: 'json',
                                prop: 'wikitext', text: text },
                        headers: { 'User-Agent' => Rails.application.credentials.wiki_user_agent },
                        **WikiHttp::OPTIONS)
        end
        return nil unless response.code == 200

        JSON.parse(response.body).dig('expandtemplates', 'wikitext')
      end

      # A page's raw wikitext through index.php?action=raw (used for the family templates,
      # Template:Weapon Skills/<name>). Returns nil unless the wiki answers 200.
      def fetch_raw(title, kind: 'family_template')
        title = Granblue::WikiTitle.normalize(title)
        return store.fetch(kind, title).body if store

        path = title.tr(' ', '_').split('/').map { |segment| ERB::Util.url_encode(segment) }.join('/')
        response = WikiHttp.with_timeouts(title) do
          HTTParty.get("https://gbf.wiki/#{path}?action=raw",
                       headers: { 'User-Agent' => Rails.application.credentials.wiki_user_agent },
                       format: :plain, **WikiHttp::OPTIONS)
        end
        response.code == 200 ? response.body.to_s.dup.force_encoding('UTF-8').scrub : nil
      end

      # The time of each page's latest edit, up to 50 titles in one request (action=query,
      # prop=revisions). → { title as given => Time, or nil when the page doesn't exist }.
      # Always live: it's how a store decides what to refetch.
      def last_edited(titles)
        raise ArgumentError, 'at most 50 titles per request' if titles.size > 50

        # Keys stored before titles were normalized can be percent-encoded ("Devil%27s Finger").
        plain = titles.index_with { |t| Granblue::WikiTitle.normalize(t) }
        response = WikiHttp.with_timeouts(titles.first) do
          HTTParty.get(base_uri,
                       query: { action: 'query', format: 'json', formatversion: 2, prop: 'revisions',
                                rvprop: 'timestamp', titles: plain.values.uniq.join('|') },
                       headers: { 'User-Agent' => Rails.application.credentials.wiki_user_agent },
                       **WikiHttp::OPTIONS)
        end
        raise WikiError.new(code: response.code, message: 'Unexpected response', page: titles.first) unless response.code == 200

        query = JSON.parse(response.body).fetch('query', {})
        normalized = Array(query['normalized']).to_h { |n| [n['from'], n['to']] }
        edited = Array(query['pages']).to_h do |p|
          [p['title'], p['missing'] ? nil : Time.zone.parse(p.dig('revisions', 0, 'timestamp').to_s)]
        end
        titles.index_with { |t| edited[normalized.fetch(plain[t], plain[t])] }
      end

      private

      def stored_page(page, kind)
        kinds = kind ? [kind.to_s] : FETCH_KINDS
        kinds.each do |k|
          return store.fetch(k, page).body
        rescue WeaponSkills::SourceStore::SourceMissing
          next
        end
        raise WeaponSkills::SourceStore::SourceMissing.new(kinds.join('|'), page)
      end

      # The stored expansion of a weapon page. Refuses one made from different wikitext
      # (the weapon's wiki_raw changed without a source fetch), which would be silently stale.
      def stored_expansion(text, page)
        raise WeaponSkills::SourceStore::SourceMissing.new('expanded', '(no page given)') if page.blank?

        raw = begin
          store.fetch('wiki_raw', page)
        rescue WeaponSkills::SourceStore::SourceMissing
          nil
        end
        if raw && raw.sha256 != Digest::SHA256.hexdigest(text.to_s)
          raise WeaponSkills::SourceStore::SourceMissing.new('expanded', "#{page} (wiki_raw changed since the fetch)")
        end

        store.fetch('expanded', page).body
      end

      def handle_response(response, page)
        case response.code
        when 200
          if response.key?('error')
            raise WikiError.new(code: response['error']['code'],
                                message: response['error']['info'],
                                page: page)
          end

          response['parse']['wikitext']['*']
        when 404
          raise WikiError.new(code: 404, message: 'Page not found', page: page)
        when 500...600
          raise WikiError.new(code: response.code, message: 'Server error', page: page)
        else
          raise WikiError.new(code: response.code, message: 'Unexpected response', page: page)
        end
      end

      def params(page)
        {
          action: 'parse',
          format: 'json',
          page: page,
          prop: @props
        }
      end
    end
  end
end
