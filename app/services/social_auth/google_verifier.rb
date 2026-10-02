# frozen_string_literal: true

module SocialAuth
  # Verifies a Google ID token.
  class GoogleVerifier < IdTokenVerifier
    JWKS_URL = 'https://www.googleapis.com/oauth2/v3/certs'
    # Google documents both forms.
    ISSUERS = ['https://accounts.google.com', 'accounts.google.com'].freeze

    private

    def build_identity(claims, _name)
      email = verified_email(claims)
      Identity.new(
        provider: 'google',
        uid: claims['sub'],
        email: email,
        is_private_email: false,
        name: nil,
        username_hint: email&.split('@')&.first || claims['given_name']
      )
    end
  end
end
