# frozen_string_literal: true

module SocialAuth
  # GETs JSON from a login provider. Any failure raises SocialAuth::Error.
  module Http
    TIMEOUT = 5 # seconds

    def self.get_json(url, headers: {})
      response = HTTParty.get(url, headers: headers, timeout: TIMEOUT, format: :plain)
      raise Error unless response.code == 200

      body = JSON.parse(response.body.to_s)
      raise Error unless body.is_a?(Hash)

      body
    rescue Error
      raise
    rescue StandardError => e
      Rails.logger.warn("[SocialAuth] request to #{URI(url).host} failed (#{e.class})")
      raise Error
    end
  end
end
