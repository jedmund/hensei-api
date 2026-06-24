# frozen_string_literal: true

# Rack::Attack blocks scanner/bot probe paths and rate-limits the API.
#
# Topology notes:
# - The API sits behind Cloudflare, so the authoritative client address is the
#   CF-Connecting-IP header (Cloudflare sets it and overwrites spoofed values).
# - The SvelteKit SSR frontend proxies many users' requests from one egress IP,
#   so authenticated traffic is throttled per access token (= per user), never
#   per IP. Per-IP limiting of public/unauthenticated traffic is left to
#   Cloudflare, which can exempt the SSR origin.
class Rack::Attack
  # Shared counter store so limits hold across all app instances: Redis in real
  # environments, in-memory locally. (Disabled entirely in test, see bottom.)
  cache.store =
    if Rails.env.local?
      ActiveSupport::Cache::MemoryStore.new
    else
      ActiveSupport::Cache::RedisCacheStore.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
    end

  def self.bearer_token(req)
    req.get_header('HTTP_AUTHORIZATION')&.slice(/\ABearer\s+(.+)\z/i, 1)
  end

  # Real client IP behind Cloudflare; falls back to Rack's IP for direct hits.
  def self.client_ip(req)
    req.get_header('HTTP_CF_CONNECTING_IP').presence || req.ip
  end

  ### Allowlist — never block or throttle the platform healthcheck. (The route
  # prefix is /v1 in production and /api/v1 elsewhere, hence end_with?.)
  safelist('healthcheck') { |req| req.path.end_with?('/version') }

  ### Blocklist — scanner/bot probe paths, answered 404 before routing.
  BOT_PATHS = %r{
    \A/(?:wp-admin|wp-login|wp-content|wp-includes|wp-json|phpmyadmin|cgi-bin|administrator)
    | \A/\.(?:env|git)
    | \.php\z
    | /favicon\.ico\z
    | /sitemap\.xml\z
  }xi
  blocklist('bot probes') { |req| BOT_PATHS.match?(req.path) }

  ### Throttle — authenticated requests per access token (= per user).
  # Limit is env-tunable so it can be adjusted without a deploy.
  throttle('api/token', limit: ->(_req) { ENV.fetch('RACK_ATTACK_TOKEN_LIMIT', '300').to_i }, period: 1.minute) do |req|
    bearer_token(req)
  end

  ### Responses
  self.blocklisted_responder = lambda do |_req|
    [404, { 'content-type' => 'application/json' }, [%({"error":"Not found"})]]
  end

  self.throttled_responder = lambda do |req|
    period = req.env.dig('rack.attack.match_data', :period)
    headers = { 'content-type' => 'application/json' }
    headers['retry-after'] = period.to_s if period
    [429, headers, [%({"error":"Rate limit exceeded. Please try again later."})]]
  end
end

# Throttling would otherwise interfere with the test suite; specs that exercise
# Rack::Attack enable it explicitly.
Rack::Attack.enabled = false if Rails.env.test?
