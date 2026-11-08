# frozen_string_literal: true

# Drops the Forwarded and Client-Ip headers before Rails reads the request's
# IP. Cloudflare and Railway identify the client with X-Forwarded-For (and
# ClientIpResolver uses CF-Connecting-IP), so these two only ever come from
# the client. Rails compares them with X-Forwarded-For and raises
# IpSpoofAttackError when they disagree, which turned every such request into
# an error report. Without them, remote_ip comes from X-Forwarded-For as it
# does for every other request. X-Client-IP is a different header and stays.
class StripClientProxyHeaders
  HEADERS = %w[HTTP_FORWARDED HTTP_CLIENT_IP].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    HEADERS.each { |header| env.delete(header) }
    @app.call(env)
  end
end

Rails.application.config.middleware.insert_before ActionDispatch::RemoteIp, StripClientProxyHeaders
