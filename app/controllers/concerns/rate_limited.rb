# frozen_string_literal: true

# Thin wrapper over ActionController::RateLimiting that uses the shared rate
# limit store and renders a JSON 429.
#
# Each limit needs a unique name: Rails keys counters by controller and name,
# so two unnamed limits in one controller would share a counter.
#
# Note: signup, login and password reset requests reach the API through the
# web app's server. Limit those per email, and keep per-IP limits generous.
module RateLimited
  extend ActiveSupport::Concern

  TOO_MANY_REQUESTS = lambda do
    render json: { error: 'Too many requests. Please try again later.' }, status: :too_many_requests
  end

  class_methods do
    def limit_requests(name, to:, within:, by: -> { client_ip }, **)
      rate_limit(to: to, within: within, by: by, name: name,
                 store: Rails.application.config.x.rate_limit_store,
                 with: TOO_MANY_REQUESTS, **)
    end
  end

  private

  # The visitor's real IP (see ClientIpResolver); request.remote_ip is a shared
  # edge proxy address in production.
  def client_ip
    @client_ip ||= ClientIpResolver.call(request)
  end

  # Normalized email from the request, for per-account limits. Falls back to
  # the client IP so requests without an email still get counted separately.
  def rate_limit_email_key
    email = params[:email].presence || params.dig(:user, :email).presence
    email ? "email:#{email.to_s.strip.downcase}" : "ip:#{client_ip}"
  end
end
