# frozen_string_literal: true

module GachaSimulation
  # Curators' "Refresh gacha rate-ups" (Admin::RefreshesController), kept in
  # Redis so every API process and the fetcher see it.
  #
  # - The catalogue epoch: Catalogue.snapshot reloads when it changes, so
  #   items added in the Database show in the banner's rate-ups right away.
  # - The re-fetch request: script/fetch_gacha_rates.rb asks for it on each
  #   run while it waits for a banner to end, and re-reads the game's banner
  #   when it's newer than the last one it acted on. Importing a banner
  #   clears it.
  module Refresh
    PREFIX = 'gacha:refresh'

    module_function

    def request!(now = Time.current)
      Sidekiq.redis do |redis|
        redis.incr("#{PREFIX}:catalogue_epoch")
        redis.set("#{PREFIX}:refetch_requested_at", now.utc.iso8601(3))
      end
    end

    # When a re-fetch was requested, if one is waiting for the fetcher
    def refetch_requested_at
      value = Sidekiq.redis { |redis| redis.get("#{PREFIX}:refetch_requested_at") }
      value && Time.iso8601(value)
    end

    def clear_refetch
      Sidekiq.redis { |redis| redis.del("#{PREFIX}:refetch_requested_at") }
    end

    # Changes whenever a curator refreshes; nil if Redis can't be read, so
    # the catalogue keeps its usual 15-minute refresh
    def catalogue_epoch
      Sidekiq.redis { |redis| redis.get("#{PREFIX}:catalogue_epoch") }.to_i
    rescue StandardError => e
      Rails.logger.warn("gacha catalogue epoch unavailable: #{e.class}")
      nil
    end
  end
end
