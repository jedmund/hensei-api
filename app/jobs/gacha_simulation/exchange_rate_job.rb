# frozen_string_literal: true

module GachaSimulation
  class ExchangeRateJob
    include Sidekiq::Job

    sidekiq_options queue: :maintenance, retry: 3

    def perform
      ExchangeRate.refresh
    end
  end
end
