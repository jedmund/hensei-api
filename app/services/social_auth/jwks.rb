# frozen_string_literal: true

module SocialAuth
  # A provider's signing keys, cached for TTL. A token signed with a key we
  # haven't seen triggers a refetch (providers rotate keys), at most once per
  # REFETCH_INTERVAL so tokens with made-up key IDs can't make us hammer the
  # provider.
  class Jwks
    TTL = 1.hour
    REFETCH_INTERVAL = 1.minute

    def initialize(url)
      @url = url
    end

    # The loader JWT.decode calls; it's called again with kid_not_found: true
    # when no cached key matches the token.
    def loader
      ->(options) { options[:kid_not_found] ? refetch : cached }
    end

    private

    attr_reader :url

    def cached
      SocialAuth.cache.read(cache_key) || fetch
    end

    def refetch
      throttled = !SocialAuth.cache.write("#{cache_key}:refetch", true, unless_exist: true, expires_in: REFETCH_INTERVAL)
      throttled ? cached : fetch
    end

    def fetch
      keys = Http.get_json(url)['keys']
      raise Error unless keys.is_a?(Array)

      jwks = { 'keys' => keys.select { |key| key.is_a?(Hash) && key['kty'] == 'RSA' && key.fetch('use', 'sig') == 'sig' } }
      SocialAuth.cache.write(cache_key, jwks, expires_in: TTL)
      jwks
    end

    def cache_key
      "jwks:#{url}"
    end
  end
end
