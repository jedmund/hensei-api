# frozen_string_literal: true

module WeaponSkills
  # Where the build reads its inputs. Fetching from gbf.wiki is one explicit step that
  # fills a store; parsing and building only ever read from it. A miss during a build
  # raises SourceMissing instead of reaching for the network.
  #
  # kinds: "wiki_raw", "expanded", "transclusion", "family_template"
  # page_kind (fetch time, from the template name): "inline", "series_template",
  # "key_determined"
  #
  # W0 defines the interface and an in-memory store for specs; W3 adds the database-backed
  # store (weapon_sources table).
  module SourceStore
    KINDS = %w[wiki_raw expanded transclusion family_template].freeze
    PAGE_KINDS = %w[inline series_template key_determined].freeze

    class SourceMissing < StandardError
      def initialize(kind, key)
        super("no stored #{kind} source for #{key.inspect}; run granblue:fetch_weapon_sources first")
      end
    end

    Source = Struct.new(:kind, :key, :body, :sha256, :fetched_at, :page_kind, keyword_init: true)

    # The contract every store implements.
    module Interface
      # → Source, or raise SourceMissing
      def fetch(kind, key) = raise(NotImplementedError)

      # → Source
      def put(kind, key, body, page_kind: nil, fetched_at: Time.current) = raise(NotImplementedError)

      def exist?(kind, key)
        fetch(kind, key)
        true
      rescue SourceMissing
        false
      end
    end

    # In-memory store for specs and dry runs.
    class Memory
      include Interface

      def initialize = @sources = {}

      def fetch(kind, key)
        @sources.fetch([kind.to_s, key.to_s]) { raise SourceMissing.new(kind, key) }
      end

      def put(kind, key, body, page_kind: nil, fetched_at: Time.current)
        raise ArgumentError, "unknown source kind #{kind}" unless KINDS.include?(kind.to_s)
        raise ArgumentError, "unknown page kind #{page_kind}" if page_kind && !PAGE_KINDS.include?(page_kind.to_s)

        @sources[[kind.to_s, key.to_s]] = Source.new(kind: kind.to_s, key: key.to_s, body: body,
                                                     sha256: Digest::SHA256.hexdigest(body.to_s),
                                                     fetched_at: fetched_at, page_kind: page_kind&.to_s)
      end
    end
  end
end
