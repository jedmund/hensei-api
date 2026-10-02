# frozen_string_literal: true

module Api
  module V1
    # Signs the browser extension in through the site, so it supports every
    # login method the site does.
    #
    # 1. POST /extension_auth/codes: the web app, with the logged-in user's
    #    token, creates a one-time code bound to the extension's PKCE
    #    challenge, and redirects it to the extension.
    # 2. POST /extension_auth/token: the extension exchanges the code and its
    #    verifier for its own tokens, the same body as POST /oauth/token. The
    #    web session's token is never handed out.
    class ExtensionAuthController < Api::V1::ApiController
      include IssuesTokens

      before_action :doorkeeper_authorize!, only: :create_code

      limit_requests 'extension-auth-code', to: 10, within: 1.minute, only: :create_code,
                                            by: -> { current_user.id }
      limit_requests 'extension-auth-token', to: 20, within: 1.minute, only: :token

      def create_code
        challenge = params[:code_challenge]
        unless ExtensionAuthCode.valid_challenge?(challenge, params[:code_challenge_method])
          return render json: { error: 'invalid_request' }, status: :unprocessable_entity
        end

        code = ExtensionAuthCode.issue(current_user, code_challenge: challenge)
        response.headers['Cache-Control'] = 'no-store'
        render json: { code: code, expires_in: ExtensionAuthCode::TTL.to_i }, status: :created
      end

      # Every failure is the same invalid_grant, so the response doesn't say
      # which check failed.
      def token
        user = ExtensionAuthCode.redeem(params[:code], params[:code_verifier])
        return render json: { error: 'invalid_grant' }, status: :bad_request unless user

        render_token_response(user)
      end
    end
  end
end
