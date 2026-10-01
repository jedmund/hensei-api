# frozen_string_literal: true

# General per-client API rate limits (Rack::Attack). These sit on top of the
# per-action auth limits in RateLimited and are deliberately generous: they
# stop bulk pulls and abusive clients, not normal use. Search traffic peaks at
# ~60 requests/minute for a single real visitor (typeaheads).
#
# Clients are keyed by their real IP (ClientIpResolver), not Rails' remote_ip,
# which is a shared edge proxy address behind Cloudflare and Railway.
#
# RATE_LIMIT_MODE=log (default) only logs clients that would be limited;
# RATE_LIMIT_MODE=enforce returns 429s.
module ApiRateLimits
  API_PATH = %r{\A(?:/api)?/v1/}
  SEARCH_PATH = %r{\A(?:/api)?/v1/search(?:/|\z)}
  ITEM_DETAIL_PATH = %r{\A(?:/api)?/v1/(?:characters|weapons|summons)/[^/]+(?:/(?:related|raw|element_variants))?\z}

  RULES = [
    { name: 'api/minute', limit: 600, period: 1.minute, path: API_PATH },
    { name: 'api/hour', limit: 10_000, period: 1.hour, path: API_PATH },
    { name: 'search/minute', limit: 120, period: 1.minute, path: SEARCH_PATH },
    { name: 'search/hour', limit: 3_000, period: 1.hour, path: SEARCH_PATH },
    { name: 'item-detail/minute', limit: 120, period: 1.minute, path: ITEM_DETAIL_PATH, get_only: true }
  ].freeze

  def self.enforce?
    ENV.fetch('RATE_LIMIT_MODE', 'log') == 'enforce'
  end

  def self.client_key(req)
    ClientIpResolver.call(ActionDispatch::Request.new(req.env))
  end

  # (Re)defines the rules: throttles when enforcing, tracks (log only) otherwise.
  def self.define!(enforce: enforce?)
    Rack::Attack.clear_configuration
    rule = enforce ? :throttle : :track

    RULES.each do |r|
      Rack::Attack.public_send(rule, r[:name], limit: r[:limit], period: r[:period]) do |req|
        next if r[:get_only] && !req.get?

        client_key(req) if req.path.match?(r[:path])
      end
    end

    Rack::Attack.throttled_responder = lambda do |req|
      retry_after = (req.env['rack.attack.match_data'] || {})[:period].to_i
      [429, { 'Content-Type' => 'application/json', 'Retry-After' => retry_after.to_s },
       [{ error: 'Too many requests. Please try again later.' }.to_json]]
    end
  end
end

ApiRateLimits.define!

Rails.application.config.after_initialize do
  Rack::Attack.cache.store = Rails.application.config.x.rate_limit_store
end

# Log the first request over each limit per period, which also shows who the
# heavy clients are while running in log mode.
ActiveSupport::Notifications.subscribe(/\A(throttle|track)\.rack_attack\z/) do |_name, _start, _finish, _id, payload|
  req = payload[:request]
  data = req.env['rack.attack.match_data'] || {}
  next unless data[:count] == data[:limit].to_i + 1

  action = req.env['rack.attack.match_type'] == :throttle ? 'blocked' : 'would_block'
  Rails.logger.warn(
    "[rate_limit] #{action} rule=#{req.env['rack.attack.matched']} key=#{data[:discriminator]} " \
    "limit=#{data[:limit]}/#{data[:period]}s path=#{req.path}"
  )
end
