# frozen_string_literal: true

module CharacterSkills
  # Spaces the editor refresh's wiki requests at least Granblue::WikiThrottle::MIN_DELAY
  # apart, per site and per process: a batch job's characters, and two editors previewing
  # at once in one Puma process, share the same clock. Pass #before_request(site) to the
  # fetchers, which call it right before each request.
  class WikiPacer
    SITES = %i[gbf_wiki gbf_wiki_jp].freeze

    class << self
      def instance
        @instance ||= new
      end

      delegate :wait, :before_request, to: :instance
    end

    def initialize(min_delay: Granblue::WikiThrottle::MIN_DELAY, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
                   sleeper: ->(seconds) { sleep(seconds) })
      @min_delay = min_delay
      @clock = clock
      @sleeper = sleeper
      @last = {}
      @mutex = Mutex.new
    end

    # Blocks until site's last request was at least min_delay ago, then marks a request now.
    def wait(site)
      raise ArgumentError, "unknown site #{site.inspect}" unless SITES.include?(site)

      @mutex.synchronize do
        if (last = @last[site])
          remaining = @min_delay - (@clock.call - last)
          @sleeper.call(remaining) if remaining.positive?
        end
        @last[site] = @clock.call
      end
    end

    def before_request(site)
      -> { wait(site) }
    end
  end
end
