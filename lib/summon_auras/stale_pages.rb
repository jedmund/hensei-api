# frozen_string_literal: true

module SummonAuras
  # Summons whose stored gbf.wiki page (wiki_raw) is likely older than the wiki, so their
  # auras miss a tier the game has. Pages are fetched once and never re-read live, so an uncap
  # the wiki adds later stays invisible until the page is refetched (Belmervolk, Nihuyvintae
  # and Zamalvoch kept their 4★ aura as active after their 5★ came out).
  #
  # A summon with a wiki title is stale when:
  #   - it has no stored page, or one with no fetch date;
  #   - its latest_date (newest uncap/transcendence) is after the fetch;
  #   - its main aura tiers stop short of its max uncap (5★ ULB, 4★ FLB, else 3★); or
  #   - it can transcend and no tier reaches transcendence stage 5.
  # The last two catch a page fetched before the wiki added a tier, whatever the dates say.
  # A summon whose wiki page still lacks the tier stays stale; refetching it is cheap.
  module StalePages
    module_function

    # → the stale summons, most recently uncapped first.
    def scope
      Summon.where.not(wiki_en: [nil, '']).where(id: stale_ids).order(latest_date: :desc, granblue_id: :asc)
    end

    def stale_ids
      fetched = Source.where(owner_type: Summon.polymorphic_name, kind: 'wiki_raw', key: '').pluck(:owner_id, :fetched_at).to_h
      top_main = SummonAura.where(slot: 'main', transcendence_stage: 0).group(:summon_granblue_id).maximum(:uncap_level)
      top_stage = SummonAura.group(:summon_granblue_id).maximum(:transcendence_stage)

      columns = %i[id granblue_id latest_date flb ulb transcendence]
      Summon.where.not(wiki_en: [nil, '']).pluck(*columns).filter_map do |row|
        summon = columns.zip(row).to_h
        id = summon[:id]
        id if stale?(summon, fetched[id], top_main[summon[:granblue_id]], top_stage[summon[:granblue_id]])
      end
    end

    def stale?(summon, fetched_at, top_tier, top_stage)
      fetched_at.nil? ||
        (summon[:latest_date].present? && summon[:latest_date] > fetched_at.to_date) ||
        short_of_uncap?(top_tier, ulb: summon[:ulb], flb: summon[:flb]) ||
        (summon[:transcendence] && !top_tier.nil? && top_stage.to_i < 5)
    end

    # A summon with main aura tiers whose top tier is below its max uncap
    def short_of_uncap?(top_tier, ulb:, flb:)
      return false if top_tier.nil?

      top_tier < (if ulb
                    5
                  else
                    (flb ? 4 : 3)
                  end)
    end

    # Refetches up to limit stale pages, at least delay seconds apart. Each stored page queues
    # the summon's aura build (Summon#enqueue_aura_build). → [fetched, errors] (granblue_ids).
    def refresh(limit: nil, delay: Granblue::WikiThrottle::MIN_DELAY, io: $stdout)
      summons = limit ? scope.limit(limit).to_a : scope.to_a
      fetcher = Granblue::WikiFetcher.new(delay: delay)
      fetched = []
      errors = []
      summons.each_with_index do |summon, index|
        Granblue::WikiThrottle.wait(delay) if index.positive?
        fetcher.fetch_and_store(summon)
        fetched << summon.granblue_id
        io.puts "  #{summon.granblue_id} #{summon.name_en}"
      rescue StandardError => e
        errors << summon.granblue_id
        io.puts "  #{summon.granblue_id} #{summon.name_en}: #{e.message}"
      end
      io.puts "refresh_stale_summon_pages: #{fetched.size} refetched, #{errors.size} errors"
      [fetched, errors]
    end
  end
end
