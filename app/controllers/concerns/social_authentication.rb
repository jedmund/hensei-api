# frozen_string_literal: true

# Shared by the social sign-in and identity-linking endpoints: verifying a
# provider assertion, the per-provider-account rate limit, and the contract's
# error bodies.
module SocialAuthentication
  extend ActiveSupport::Concern

  # Attempts per provider account, shared by sign-in and linking.
  PROVIDER_UID_LIMIT = 10
  PROVIDER_UID_WINDOW = 15.minutes

  private

  # Returns a SocialAuth::Identity, or raises SocialAuth::Error.
  def verify_social_assertion(provider)
    SocialAuth.verify(provider, assertion: params[:assertion], nonce: params[:nonce], name: params[:name])
  end

  # Renders a 429 and returns true when this provider account has made too
  # many attempts. Runs after verification, so only real accounts are counted.
  def provider_uid_rate_limited?(identity)
    rate_limit_exceeded!('social-provider-uid', "#{identity.provider}:#{identity.uid}",
                         to: PROVIDER_UID_LIMIT, within: PROVIDER_UID_WINDOW)
  end

  def render_invalid_assertion
    render json: { error: 'invalid_assertion' }, status: :unauthorized
  end

  def render_invalid_ticket
    render json: { error: 'invalid_ticket' }, status: :unauthorized
  end
end
