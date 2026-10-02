# frozen_string_literal: true

# Issues a Doorkeeper access token and refresh token for a user and renders the
# same body POST /oauth/token returns (see TokensController), so the web app's
# session cookies and the refresh_token grant work unchanged.
module IssuesTokens
  extend ActiveSupport::Concern

  private

  def render_token_response(user, status: :ok)
    token = Doorkeeper::AccessToken.create_for(
      application: nil,
      resource_owner: user,
      scopes: '',
      use_refresh_token: true,
      expires_in: Doorkeeper.config.access_token_expires_in
    )
    token_response = Doorkeeper::OAuth::TokenResponse.new(token)

    headers.merge!(token_response.headers)
    render json: token_response.body.merge(user: user.token_payload), status: status
  end
end
