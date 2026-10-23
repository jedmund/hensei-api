# frozen_string_literal: true

module WeaponSkills
  module SourceStore
    # Used only by the fetch step. It finds the pages a weapon's structural parse follows
    # (transclusions, templates), because the parse discovers them as it goes. The structure
    # compiler reads through it once per weapon (Fetcher#record_followed_pages), and it
    # answers each request for a recordable kind from the network and remembers it. The
    # caller writes `recorded` to the real store afterwards. Other kinds miss, as offline.
    class Recording
      include Interface

      attr_reader :recorded, :failures

      # fetch_page: ->(key) { body }, the network fetch (memoised by the caller across a run).
      def initialize(fetch_page:, kinds: %w[transclusion])
        @fetch_page = fetch_page
        @kinds = kinds.map(&:to_s)
        @recorded = {}
        @failures = []
      end

      def fetch(kind, key)
        raise SourceMissing.new(kind, key) unless @kinds.include?(kind.to_s)

        if (body = @recorded[[kind.to_s, key.to_s]])
          return source(kind, key, body)
        end

        begin
          body = @fetch_page.call(key.to_s)
        rescue StandardError => e
          # The caller reads a failure as a miss, so remember it here for the fetch report.
          @failures << { kind: kind.to_s, key: key.to_s, error: "#{e.class}: #{e.message}" }
          raise
        end
        @recorded[[kind.to_s, key.to_s]] = body
        source(kind, key, body)
      end

      def put(kind, key, body, page_kind: nil, fetched_at: Time.current)
        @recorded[[kind.to_s, key.to_s]] = body
        source(kind, key, body, page_kind: page_kind, fetched_at: fetched_at)
      end

      private

      def source(kind, key, body, page_kind: nil, fetched_at: Time.current)
        Source.new(kind: kind.to_s, key: key.to_s, body: body, sha256: Digest::SHA256.hexdigest(body.to_s),
                   fetched_at: fetched_at, page_kind: page_kind)
      end
    end
  end
end
