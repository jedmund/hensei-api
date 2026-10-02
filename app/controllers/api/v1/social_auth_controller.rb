# frozen_string_literal: true

module Api
  module V1
    # POST /auth/:provider: turns a provider's proof of identity into Hensei
    # tokens, or into a ticket for the follow-up step.
    #
    # 1. Known identity: tokens, the same body as POST /oauth/token.
    # 2. Unknown identity, and no user has the provider's verified email: a
    #    signup ticket for the username step.
    # 3. Unknown identity, and the verified email belongs to a user: a link
    #    ticket. Never linked automatically; the user logs in with their
    #    password first.
    class SocialAuthController < Api::V1::ApiController
      include IssuesTokens
      include SocialAuthentication

      # Requests arrive via the web app's server, which forwards the client IP.
      limit_requests 'social-auth', to: 30, within: 1.minute, only: :create

      before_action :ensure_provider_enabled

      def create
        identity = verify_social_assertion(provider)
        return if provider_uid_rate_limited?(identity)

        linked = UserIdentity.includes(:user).find_by(provider: identity.provider, provider_uid: identity.uid)
        return sign_in(linked) if linked

        if identity.email_verified? && User.exists?(email: identity.email)
          render_link_required(identity)
        else
          render_signup_required(identity)
        end
      rescue SocialAuth::Error
        render_invalid_assertion
      end

      private

      def provider
        params[:provider].to_s
      end

      def ensure_provider_enabled
        render_not_found_response('provider') unless SocialAuth.enabled?(provider)
      end

      def sign_in(linked)
        linked.update_column(:last_used_at, Time.current)
        render_token_response(linked.user)
      end

      def render_link_required(identity)
        render json: {
          status: 'link_required',
          ticket: SocialAuth::Ticket.issue(identity, purpose: :link),
          provider: identity.provider
        }
      end

      def render_signup_required(identity)
        render json: {
          status: 'signup_required',
          ticket: SocialAuth::Ticket.issue(identity, purpose: :signup),
          suggested_username: SocialAuth::UsernameSuggester.call(identity.username_hint),
          email_required: !identity.email_verified?
        }
      end
    end
  end
end
