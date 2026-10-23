# frozen_string_literal: true

module SocialAuth
  # Verifies an OpenID Connect ID token: the signature against the provider's
  # JWKS, then iss, aud, exp and nonce. Subclasses set the provider details and
  # build the identity from the claims.
  class IdTokenVerifier
    ALGORITHMS = ['RS256'].freeze

    def initialize(client_id:)
      @client_id = client_id
    end

    def call(assertion:, nonce:, name: nil)
      raise Error unless nonce.is_a?(String) && nonce.present?

      claims = decode(assertion)
      raise Error unless claims['nonce'].is_a?(String) && ActiveSupport::SecurityUtils.secure_compare(claims['nonce'], nonce)
      raise Error unless claims['sub'].is_a?(String) && claims['sub'].present?

      build_identity(claims, name)
    end

    private

    attr_reader :client_id

    def decode(assertion)
      claims, = JWT.decode(
        assertion, nil, true,
        algorithms: ALGORITHMS,
        jwks: self.class.jwks.loader,
        iss: self.class::ISSUERS, verify_iss: true,
        aud: client_id, verify_aud: true,
        verify_expiration: true,
        required_claims: %w[iss aud exp sub nonce]
      )
      claims
    end

    # Google sends booleans; Apple may send the strings "true" and "false".
    def truthy_claim?(value)
      [true, 'true'].include?(value)
    end

    def verified_email(claims)
      email = claims['email']
      return nil unless email.is_a?(String) && email.present? && truthy_claim?(claims['email_verified'])

      email.strip.downcase
    end

    class << self
      def jwks
        Jwks.new(self::JWKS_URL)
      end
    end
  end
end
