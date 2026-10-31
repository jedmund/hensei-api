# frozen_string_literal: true

module Api
  module V1
    # Records a view of a team page. Only the web app's server calls this,
    # after the page has rendered in the visitor's browser, so it requires
    # the internal secret; the visitor comes from the forwarded session token
    # or X-Client-IP (see ClientIpResolver), never from params. Always
    # answers 204 so the response says nothing about whether a view counted.
    class PartyViewsController < Api::V1::ApiController
      before_action :require_internal_call
      limit_requests 'party-view', to: 120, within: 1.minute, by: -> { current_user&.id || client_ip }
      before_action :set_party

      # POST /parties/:id/view   (:id is the party UUID)
      def create
        PartyViews::Recorder.record(party_id: @party.id, user: current_user, ip: visitor_ip) if countable?
        head :no_content
      rescue RedisClient::Error => e
        # A lost view isn't worth failing the request over.
        Rails.logger.warn("[party_views] not recorded: #{e.class}")
        head :no_content
      end

      private

      def require_internal_call
        secret = ENV['API_INTERNAL_SECRET'].presence
        provided = request.headers['X-Internal-Secret'].to_s
        return if secret && provided.bytesize == secret.bytesize &&
                  ActiveSupport::SecurityUtils.secure_compare(provided, secret)

        render json: { error: 'Forbidden' }, status: :forbidden
      end

      def set_party
        @party = Party.find_by(id: params[:id].to_s[UUID_FORMAT])
        head :no_content unless @party
      end

      # Only public teams can trend; owners viewing their own team don't count.
      def countable?
        return false unless @party.public?
        return false if current_user && @party.user_id == current_user.id

        current_user.present? || visitor_ip.present?
      end

      # Only a public address forwarded by the web server; never the edge IP.
      def visitor_ip
        @visitor_ip ||= ClientIpResolver.public_ip(request.headers['X-Client-IP'])
      end
    end
  end
end
