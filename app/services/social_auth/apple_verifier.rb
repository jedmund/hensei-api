# frozen_string_literal: true

module SocialAuth
  # Verifies a Sign in with Apple ID token. Apple sends the user's name only on
  # the first sign-in, outside the token; the web app passes it through as
  # `name` (a string, or Apple's { firstName, lastName }).
  class AppleVerifier < IdTokenVerifier
    JWKS_URL = 'https://appleid.apple.com/auth/keys'
    ISSUERS = ['https://appleid.apple.com'].freeze
    MAX_NAME_LENGTH = 100

    private

    def build_identity(claims, name)
      email = verified_email(claims)
      private_email = truthy_claim?(claims['is_private_email'])
      name = normalize_name(name)
      Identity.new(
        provider: 'apple',
        uid: claims['sub'],
        email: email,
        is_private_email: private_email,
        name: name,
        username_hint: name || (email&.split('@')&.first unless private_email)
      )
    end

    def normalize_name(name)
      name = name.to_unsafe_h if name.respond_to?(:to_unsafe_h)
      value = case name
              when String then name
              when Hash then name.values_at('firstName', 'lastName').grep(String).join(' ')
              end
      value&.squish&.first(MAX_NAME_LENGTH).presence
    end
  end
end
