# frozen_string_literal: true

module SummonAuras
  # Weekly: refetches summon pages that are likely older than gbf.wiki (SummonAuras::StalePages),
  # so a new uncap's aura shows up without anyone refetching by hand. Capped per run; at least
  # 2s between requests. Each stored page queues that summon's aura build.
  class RefreshStalePagesJob < ApplicationJob
    queue_as :maintenance

    LIMIT = 25

    def perform
      log = StringIO.new
      StalePages.refresh(limit: LIMIT, io: log)
      log.string.lines.each { |line| Rails.logger.info "[SUMMON_PAGES] #{line.strip}" }
    end
  end
end
