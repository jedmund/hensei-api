# frozen_string_literal: true

# Social login: verifies a login provider's proof of who the user is (an ID
# token for Google and Apple, an access token for Discord) and returns the
# provider identity.
#
# Every verification failure raises SocialAuth::Error, whatever the cause, so
# callers can't tell (and can't reveal) which check failed.
module SocialAuth
  class Error < StandardError; end

  # Provider => the environment variable holding our client ID. A provider is
  # enabled when its variable is set.
  CLIENT_ID_VARIABLES = {
    'discord' => 'DISCORD_CLIENT_ID',
    'google' => 'GOOGLE_CLIENT_ID',
    'apple' => 'APPLE_SERVICES_ID'
  }.freeze

  class << self
    def client_id(provider)
      variable = CLIENT_ID_VARIABLES[provider.to_s]
      variable && ENV.fetch(variable, nil).presence
    end

    def enabled?(provider)
      client_id(provider).present?
    end

    # Returns a SocialAuth::Identity, or raises SocialAuth::Error.
    def verify(provider, assertion:, nonce: nil, name: nil)
      client_id = client_id(provider)
      raise Error unless client_id && assertion.is_a?(String) && assertion.present?

      verifier_for(provider).new(client_id: client_id).call(assertion: assertion, nonce: nonce, name: name)
    rescue Error
      raise
    rescue StandardError => e
      # Only the class: messages can include claim values.
      Rails.logger.warn("[SocialAuth] #{provider} verification failed (#{e.class})")
      raise Error
    end

    def cache
      Rails.application.config.x.social_auth_cache
    end

    private

    def verifier_for(provider)
      case provider.to_s
      when 'discord' then DiscordVerifier
      when 'google' then GoogleVerifier
      when 'apple' then AppleVerifier
      else raise Error
      end
    end
  end
end
