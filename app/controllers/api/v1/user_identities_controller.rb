# frozen_string_literal: true

module Api
  module V1
    # The current user's linked login providers (/users/me/identities).
    class UserIdentitiesController < Api::V1::ApiController
      include SocialAuthentication

      before_action :doorkeeper_authorize!

      limit_requests 'identity-link', to: 20, within: 1.minute, only: :create

      def index
        identities = current_user.user_identities.order(:created_at)
        render json: identities.map(&:as_api_json)
      end

      # Links a provider, from a link ticket (the "log in to link" prompt) or
      # from a fresh provider assertion (settings).
      def create
        identity = params[:link_ticket].present? ? identity_from_ticket : identity_from_assertion
        return if performed?

        link(identity)
      end

      # Refuses to remove the account's last way to log in. The row lock keeps
      # two concurrent unlinks from both passing that check.
      def destroy
        current_user.with_lock do
          identity = current_user.user_identities.find_by(provider: params[:provider].to_s)
          if identity.nil?
            render_not_found_response('identity')
          elsif last_login_method?(identity)
            render json: { error: 'last_login_method' }, status: :unprocessable_entity
          else
            identity.destroy!
            head :no_content
          end
        end
      end

      private

      # A link ticket is only good for the account whose email matched, and only
      # for a session that logged in after the ticket was issued. Every failure
      # is the same invalid_ticket, so the response reveals nothing.
      def identity_from_ticket
        ticket = SocialAuth::Ticket.read(params[:link_ticket], purpose: :link)
        return render_invalid_ticket unless usable_link_ticket?(ticket)

        SocialAuth::Identity.new(
          provider: ticket['provider'],
          uid: ticket['provider_uid'],
          email: (ticket['email'] if ticket['email_verified'] == true),
          is_private_email: ticket['is_private_email'] == true
        )
      end

      def usable_link_ticket?(ticket)
        ticket.present? &&
          ticket['user_id'].to_s == current_user.id.to_s &&
          doorkeeper_token.created_at > SocialAuth::Ticket.issued_at(ticket)
      end

      def identity_from_assertion
        provider = params[:provider].to_s
        return render_invalid_assertion unless SocialAuth.enabled?(provider)

        identity = verify_social_assertion(provider)
        provider_uid_rate_limited?(identity) ? nil : identity
      rescue SocialAuth::Error
        render_invalid_assertion
      end

      def link(identity)
        existing = UserIdentity.find_by(provider: identity.provider, provider_uid: identity.uid)
        return render_conflict('identity_taken') if existing && existing.user_id != current_user.id
        return render_conflict('provider_already_linked') if existing || current_user.user_identities.exists?(provider: identity.provider)

        linked = current_user.user_identities.create!(
          provider: identity.provider,
          provider_uid: identity.uid,
          email: identity.email,
          email_verified: identity.email_verified?,
          is_private_email: identity.is_private_email ? true : false,
          last_used_at: Time.current
        )
        render json: linked.as_api_json, status: :created
      rescue ActiveRecord::RecordNotUnique
        render_conflict('identity_taken')
      rescue ActiveRecord::RecordInvalid => e
        # Lost a race with another link of the same identity or provider.
        render_conflict(e.record.errors[:provider_uid].any? ? 'identity_taken' : 'provider_already_linked')
      end

      def last_login_method?(identity)
        !current_user.password? && current_user.user_identities.where.not(id: identity.id).none?
      end

      def render_conflict(error)
        render json: { error: error }, status: :conflict
      end
    end
  end
end
