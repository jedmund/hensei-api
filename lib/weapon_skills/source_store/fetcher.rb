# frozen_string_literal: true

module WeaponSkills
  module SourceStore
    # The one step that talks to gbf.wiki. It fills a store with everything the weapon-skill
    # parse reads:
    #   wiki_raw         a weapon's page (also written to weapons.wiki_raw)
    #   expanded         expandtemplates output for series-template pages and pages whose
    #                    structural parse leaves {{…}} in skill names
    #   transclusion     pages and templates the structural parse follows
    #   family_template  Template:Weapon Skills/<family>
    # plus the key series pages KeySkillExtractor reads (wiki_raw, no weapon).
    #
    # Polite by default: one request per `delay` seconds, retries with backoff on 429, 5xx
    # and network errors, and pages several weapons share are fetched once per run.
    class Fetcher
      WEAPON_KINDS = %w[wiki_raw expanded transclusion].freeze
      # An expanded page whose skills come from an equipped key (Dark Opus, Destroyer,
      # Draconic, Ultima) names the key slot in place of a skill.
      # (ExpandedWeaponSkillImporter::KEY_SLOT has the same phrases, but its /x flag drops
      # their spaces, so it never matches them.)
      KEY_PLACEHOLDER = /granted\ power\ with\ an?\ (?:anklet|pendulum|teluma|chain)
                         |empowered\ by\ a\ chosen\ (?:pendulum|teluma)
                         |a\ gate\ to\ the\ summits
                         |(?:locked|sealed)\ within\ ultima/xi
      ENGLISH_S1_DESC = /^\|\s*s1_desc\s*=/
      RETRYABLE_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, Errno::ECONNREFUSED,
                          Errno::ETIMEDOUT, SocketError, OpenSSL::SSL::SSLError, EOFError].freeze

      attr_reader :stats, :failures

      def initialize(store: Database.new, wiki: Granblue::Parsers::Wiki.new(store: nil), delay: 0.5,
                     retries: 4, backoff: 5.0, log: nil)
        @store = store
        @wiki = wiki
        @delay = delay
        @retries = retries
        @backoff = backoff
        @log = log
        @stats = Hash.new(0)
        @failures = []
        @page_memo = {}
      end

      # page_kind of a weapon page, decided at fetch time from its template.
      def self.page_kind(wiki_raw, expanded = nil)
        return "key_determined" if expanded.to_s.match?(KEY_PLACEHOLDER)
        # Same rule as EntityReparser#template_only_wikitext?: the template supplies the
        # skills unless the page has an English "|s1_desc=" line ("|jps1_desc=" doesn't count).
        if wiki_raw.to_s.include?("{{Weapon/Common/") && !wiki_raw.to_s.match?(ENGLISH_S1_DESC)
          return "series_template"
        end

        "inline"
      end

      # Fetches and stores one weapon's sources. Raises when the page itself can't be
      # fetched; expansion and transclusion failures are recorded in `failures`.
      def fetch_weapon(weapon, kinds: WEAPON_KINDS)
        kinds = kinds.map(&:to_s)
        raise ArgumentError, "#{weapon.granblue_id} has no wiki page" if weapon.wiki_en.blank?

        text = kinds.include?("wiki_raw") ? fetch_page_text(weapon) : weapon.wiki_raw.to_s
        page = weapon.wiki_en
        followed, garbled = record_followed_pages(weapon) if kinds.include?("transclusion") || kinds.include?("expanded")

        expanded = nil
        if kinds.include?("expanded") && (text.include?("{{Weapon/Common/") || garbled)
          expanded = request("expand #{page}") { @wiki.expand(text).presence || raise(EmptyResponse, "empty expansion") }
          failed("expanded", page, weapon, @last_error) if expanded.nil?
        end
        expanded ||= stored_body("expanded", page)
        kind_of_page = self.class.page_kind(text, expanded)

        WeaponSource.transaction do
          if kinds.include?("wiki_raw")
            put("wiki_raw", page, text, weapon, kind_of_page)
            WeaponSource.where(weapon_id: weapon.id, kind: "wiki_raw").where.not(key: page).delete_all
          end
          put("expanded", page, expanded, weapon, kind_of_page) if expanded && kinds.include?("expanded")
          store_followed(weapon, followed) if kinds.include?("transclusion")
        end
        text
      end

      # Pages no single weapon owns: family templates (action=raw) and key series pages.
      def fetch_family_template(name)
        title = Granblue::Extractors::FamilyTemplateImporter.template_title(name)
        body = request("family #{name}") { @wiki.fetch_raw(title).presence || raise(EmptyResponse, "no template") }
        return failed("family_template", title, nil, @last_error) if body.nil?

        put("family_template", title, body, nil, nil)
      end

      def fetch_series_page(title)
        body = request("series #{title}") { @wiki.fetch(title) }
        return failed("wiki_raw", title, nil, @last_error) if body.nil?

        put("wiki_raw", title, body, nil, nil)
      end

      class EmptyResponse < StandardError; end

      private

      # The weapon page, following a #REDIRECT once (and pointing wiki_en at the target),
      # also written to weapons.wiki_raw like WikiFetcher always did.
      def fetch_page_text(weapon)
        text = request!("page #{weapon.wiki_en}") { @wiki.fetch(weapon.wiki_en) }
        if (redirect = text.match(/#REDIRECT \[\[(.*?)\]\]/))
          weapon.update!(wiki_en: redirect[1])
          text = request!("page #{redirect[1]}") { @wiki.fetch(redirect[1]) }
        end
        weapon.update!(wiki_raw: text, wiki_raw_fetched_at: Time.current)
        text
      end

      # Runs the weapon's structural parse once, rolled back, through a recording store, to
      # find the pages it follows. Also reports whether the parse leaves template artifacts
      # in skill names, which EntityReparser then repairs by expansion.
      def record_followed_pages(weapon)
        recording = Recording.new(fetch_page: ->(key) { shared_page(key) })
        garbled = false
        Granblue::Parsers::WeaponParser.page_cache.clear
        Granblue::Parsers::Wiki.offline(store: recording) do
          ActiveRecord::Base.transaction(requires_new: true) do
            Granblue::Parsers::WeaponParser.new(granblue_id: weapon.granblue_id).persist_skills_from_wiki_raw
            garbled = garbled_names?(weapon)
            raise ActiveRecord::Rollback
          end
        end
        Granblue::Parsers::WeaponParser.page_cache.clear
        recording.failures.each { |f| failed(f[:kind], f[:key], weapon, f[:error]) }
        [recording.recorded, garbled]
      end

      def garbled_names?(weapon)
        WeaponSkillVersion.joins(:weapon_skill, :skill)
                          .where(weapon_skills: { weapon_granblue_id: weapon.granblue_id })
                          .exists?(["skills.name_en LIKE ?", "%{{%"])
      rescue ActiveRecord::StatementInvalid # the parse failed mid-transaction
        false
      end

      def store_followed(weapon, followed)
        followed.each { |(kind, key), body| put(kind, key, body, weapon, nil) }
        stale = WeaponSource.where(weapon_id: weapon.id, kind: "transclusion")
        stale = stale.where.not(key: followed.keys.map(&:last)) if followed.any?
        stale.delete_all
      end

      # A followed page, fetched once per run however many weapons follow it.
      def shared_page(key)
        @page_memo.fetch(key) do
          @page_memo[key] = request!("follow #{key}") { @wiki.fetch(key) }
        end
      end

      def stored_body(kind, key)
        @store.fetch(kind, key).body
      rescue SourceMissing
        nil
      end

      def put(kind, key, body, weapon, page_kind)
        if @store.is_a?(Database)
          @store.put(kind, key, body, page_kind: page_kind, weapon_id: weapon&.id)
        else
          @store.put(kind, key, body, page_kind: page_kind)
        end
        @stats[kind] += 1
      end

      def failed(kind, key, weapon, error)
        @failures << { kind: kind, key: key, weapon: weapon&.granblue_id, error: error.to_s }
        @stats["#{kind}_failed"] += 1
        nil
      end

      def request!(label, &)
        result = request(label, &)
        raise(@last_error_exception || EmptyResponse.new(label)) if result.nil?

        result
      end

      # Throttled call with retries. Returns nil (and sets @last_error) once a failure is
      # final: a 404 or missing page fails at once, transient errors after `retries`.
      def request(label)
        attempt = 0
        @last_error = @last_error_exception = nil
        begin
          sleep(@delay) if @delay.positive?
          @stats["requests"] += 1
          yield
        rescue Granblue::WikiError, EmptyResponse, *RETRYABLE_ERRORS => e
          if retryable?(e) && attempt < @retries
            attempt += 1
            wait = @backoff * (2**(attempt - 1))
            @log&.call("  retry #{attempt}/#{@retries} in #{wait}s: #{label} (#{e.class}: #{e.message})")
            sleep(wait)
            retry
          end
          @last_error = "#{e.class}: #{e.message}"
          @last_error_exception = e
          nil
        end
      end

      def retryable?(error)
        return true if RETRYABLE_ERRORS.any? { |k| error.is_a?(k) }
        return error.message != "no template" if error.is_a?(EmptyResponse)

        code = error.code.to_i
        code == 429 || code >= 500
      end
    end
  end
end
