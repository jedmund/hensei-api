# frozen_string_literal: true

require 'net/http'
module GachaSimulation
  class ExchangeRate
    KEY = 'gacha:exchange:usd-jpy'
    def self.refresh
      uri = URI('https://api.frankfurter.dev/v2/rate/USD/JPY?providers=ecb')
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) { |http| http.get(uri.request_uri) }
      raise Unavailable, 'Currency provider unavailable' unless response.is_a?(Net::HTTPSuccess)

      quote = JSON.parse(response.body)
      rate = BigDecimal(quote.fetch('rate').to_s)
      date = Date.iso8601(quote.fetch('date'))
      raise Unavailable, 'Invalid currency quote' unless rate.finite? && rate.positive? && date <= Date.today && date >= Date.today - 7

      value = { 'provider' => 'Frankfurter / ECB', 'date' => date.iso8601, 'jpy_per_usd' => rate.to_s('F') }
      Sidekiq.redis { |redis| redis.set(KEY, JSON.generate(value), ex: 8 * 86400) }
      value
    end

    def self.quote
      raw = Sidekiq.redis { |redis| redis.get(KEY) }
      return nil unless raw

      quote = JSON.parse(raw)
      age = (Date.today - Date.iso8601(quote.fetch('date'))).to_i
      return nil unless (0..7).cover?(age)

      Rails.logger.info("gacha exchange_rate_age_days=#{age}")
      quote.merge('stale' => age.positive?)
    rescue StandardError => e
      Rails.logger.warn("gacha exchange quote unavailable: #{e.class}")
      nil
    end

    def self.cost(draws)
      count = BigDecimal(draws.to_s) / 10
      crystals = count * BigDecimal(ENV.fetch('GACHA_CRYSTALS_PER_TEN', '3000'))
      jpy = count * BigDecimal(ENV.fetch('GACHA_JPY_PER_TEN', '3150'))
      quote = self.quote
      { 'crystals' => crystals.to_s('F'), 'jpy' => jpy.to_s('F'),
        'usd' => quote ? (jpy / BigDecimal(quote['jpy_per_usd'])).round(2).to_s('F') : nil,
        'exchange_rate' => quote, 'label' => 'Purchase estimate; USD reference rate excludes payment-provider conversion charges' }
    end
  end
end
