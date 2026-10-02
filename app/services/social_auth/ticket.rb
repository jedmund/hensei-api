# frozen_string_literal: true

module SocialAuth
  # Signed, purpose-scoped tickets that carry a verified provider identity from
  # POST /auth/:provider to the follow-up step: :signup (pick a username) or
  # :link (log in with a password, then link). Nothing is stored server-side,
  # and provider tokens are never included.
  module Ticket
    PURPOSES = %i[signup link].freeze
    EXPIRES_IN = 10.minutes

    class << self
      def issue(identity, purpose:)
        raise ArgumentError, "unknown ticket purpose: #{purpose}" unless PURPOSES.include?(purpose)

        payload = identity.ticket_payload.merge('iat' => Time.current.to_f)
        verifier.generate(payload, purpose: purpose, expires_in: EXPIRES_IN)
      end

      # The payload (string keys, with 'iat' as epoch seconds), or nil when the
      # ticket is missing, tampered with, expired or for another purpose.
      def read(ticket, purpose:)
        return nil unless ticket.is_a?(String) && ticket.present?

        payload = verifier.verified(ticket, purpose: purpose)
        valid_payload?(payload) ? payload : nil
      rescue StandardError
        nil
      end

      # When the ticket was issued.
      def issued_at(payload)
        Time.zone.at(payload['iat'].to_f)
      end

      private

      def valid_payload?(payload)
        payload.is_a?(Hash) &&
          UserIdentity::PROVIDERS.include?(payload['provider']) &&
          payload['provider_uid'].is_a?(String) && payload['provider_uid'].present? &&
          payload['iat'].is_a?(Numeric)
      end

      def verifier
        Rails.application.message_verifier(:social_identity)
      end
    end
  end
end
