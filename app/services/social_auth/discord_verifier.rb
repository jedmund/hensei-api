# frozen_string_literal: true

module SocialAuth
  # Verifies a Discord access token. Discord has no ID token, so the token is
  # only trusted after /oauth2/@me confirms it was issued to our application;
  # otherwise a token any Discord app obtained would be accepted.
  class DiscordVerifier
    AUTHORIZATION_URL = 'https://discord.com/api/oauth2/@me'
    USER_URL = 'https://discord.com/api/users/@me'

    def initialize(client_id:)
      @client_id = client_id
    end

    def call(assertion:, nonce: nil, name: nil) # rubocop:disable Lint/UnusedMethodArgument
      headers = { 'Authorization' => "Bearer #{assertion}" }
      authorization = Http.get_json(AUTHORIZATION_URL, headers: headers)
      application_id = authorization.dig('application', 'id').to_s
      raise Error unless ActiveSupport::SecurityUtils.secure_compare(application_id, client_id)

      build_identity(Http.get_json(USER_URL, headers: headers), authorization)
    end

    private

    attr_reader :client_id

    def build_identity(user, authorization)
      uid = user['id'].to_s
      raise Error if uid.blank?

      # The authorization's user, when present, must be the same account.
      authorized_uid = authorization.dig('user', 'id')
      raise Error if authorized_uid && authorized_uid.to_s != uid

      Identity.new(
        provider: 'discord',
        uid: uid,
        email: verified_email(user),
        is_private_email: false,
        name: nil,
        username_hint: user['username']
      )
    end

    def verified_email(user)
      email = user['email']
      return nil unless user['verified'] == true && email.is_a?(String) && email.present?

      email.strip.downcase
    end
  end
end
