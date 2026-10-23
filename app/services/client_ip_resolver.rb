# frozen_string_literal: true

require 'ipaddr'

# Resolves the visitor's real IP for rate limiting.
#
# Requests reach the API through Cloudflare and Railway's edge, so Rails'
# remote_ip is a shared edge proxy address. The visitor's address is, in order:
#
# 1. X-Client-IP, when the web app's server sends it with a valid
#    X-Internal-Secret (requests it makes while rendering pages).
# 2. CF-Connecting-IP, when the request is trusted as coming from Cloudflare:
#    always if CLOUDFLARE_ORIGIN_SECRET is unset, otherwise only when
#    X-Origin-Auth (added by a Cloudflare Transform Rule) matches it or
#    CLOUDFLARE_ORIGIN_SECRET_PREVIOUS.
# 3. Rails' remote_ip.
#
# Only public addresses are accepted from headers. Misconfigured secrets fail
# open to remote_ip, with a throttled warning.
class ClientIpResolver
  NON_PUBLIC_RANGES = [
    IPAddr.new('0.0.0.0/8'), IPAddr.new('100.64.0.0/10'), IPAddr.new('192.0.0.0/24'),
    IPAddr.new('198.18.0.0/15'), IPAddr.new('224.0.0.0/3'), IPAddr.new('::/128'),
    IPAddr.new('64:ff9b::/96'), IPAddr.new('ff00::/8')
  ].freeze
  WARN_INTERVAL = 60 # seconds

  class << self
    def call(request)
      internal_client_ip(request) || cloudflare_client_ip(request) || request.remote_ip
    end

    def public_ip(value)
      return nil if value.blank?

      addr = IPAddr.new(value.to_s.strip)
      addr = addr.native
      return nil if addr.private? || addr.loopback? || addr.link_local?
      return nil if NON_PUBLIC_RANGES.any? { |range| range.family == addr.family && range.include?(addr) }

      addr.to_s
    rescue IPAddr::Error
      nil
    end

    private

    def internal_client_ip(request)
      secret = ENV['API_INTERNAL_SECRET'].presence
      return nil unless secret

      provided = request.headers['X-Internal-Secret']
      return nil if provided.blank?
      return warn_once(:internal) unless secure_match?(provided, secret)

      public_ip(request.headers['X-Client-IP'])
    end

    def cloudflare_client_ip(request)
      ip = public_ip(request.headers['CF-Connecting-IP'])
      return nil unless ip

      secrets = [ENV.fetch('CLOUDFLARE_ORIGIN_SECRET', nil), ENV.fetch('CLOUDFLARE_ORIGIN_SECRET_PREVIOUS', nil)].filter_map(&:presence)
      return ip if secrets.empty?

      provided = request.headers['X-Origin-Auth']
      return ip if provided.present? && secrets.any? { |secret| secure_match?(provided, secret) }

      warn_once(:cloudflare)
    end

    def secure_match?(provided, secret)
      provided.bytesize == secret.bytesize && ActiveSupport::SecurityUtils.secure_compare(provided, secret)
    end

    # Logs at most once per WARN_INTERVAL per kind so a misconfigured secret is
    # visible without flooding the logs. Returns nil.
    def warn_once(kind)
      @last_warned ||= {}
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      return nil if @last_warned[kind] && now - @last_warned[kind] < WARN_INTERVAL

      @last_warned[kind] = now
      Rails.logger.warn("[client_ip] #{kind} secret mismatch; falling back to remote_ip")
      nil
    end
  end
end
