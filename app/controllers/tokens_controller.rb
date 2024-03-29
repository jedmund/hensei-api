# frozen_string_literal: true

class TokensController < Doorkeeper::TokensController
  # Overriding create action
  # POST /oauth/token
  def create
    response = strategy.authorize
    body = response.body

    if response.status == :ok
      # User the resource_owner_id from token to identify the user
      user = begin
        User.find(response.token.resource_owner_id)
      rescue StandardError
        nil
      end

      unless user.nil?
        ### If you want to render user with template
        ### create an ActionController to render out the user
        # ac = ActionController::Base.new()
        # user_json = ac.render_to_string( template: 'api/users/me', locals: { user: user})
        # body[:user] = Oj.load(user_json)

        ### Or if you want to just append user using 'as_json'
        body[:user] = {
          id: user.id,
          username: user.username,
          role: user.role
        }

      end
    end

    headers.merge! response.headers
    self.response_body = body.to_json
    self.status = response.status
  rescue Doorkeeper::Errors::DoorkeeperError => e
    handle_token_exception e
  end
end
