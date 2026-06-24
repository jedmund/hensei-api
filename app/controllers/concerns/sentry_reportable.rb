# frozen_string_literal: true

# Reports unexpected exceptions to Sentry with request/user context.
#
# Wired only into the catch-all rescue handlers (ApiController's global
# `rescue_from StandardError` and ImportController's local rescue) so that
# genuine bugs — which those handlers would otherwise swallow before Sentry's
# middleware could see them — are still reported. Expected/user-facing errors
# have their own rescue_from handlers and never reach this method; the Sentry
# initializer's excluded_exceptions list is a second safety net.
module SentryReportable
  extend ActiveSupport::Concern

  private

  # Report an unexpected exception to Sentry with request/user context.
  # No-op when Sentry isn't initialized (e.g. development/test, or no DSN).
  #
  # @param exception [Exception] the exception to report
  # @param extra [Hash] optional extra context attached under "details"
  # @return [void]
  def report_unexpected_exception(exception, extra = {})
    return unless defined?(Sentry) && Sentry.initialized?

    Sentry.with_scope do |scope|
      scope.set_user(id: current_user&.id) if respond_to?(:current_user)
      scope.set_context('request', {
                          controller: controller_name,
                          action: action_name,
                          path: request&.path,
                          method: request&.request_method
                        })
      scope.set_context('details', extra) if extra.present?
      Sentry.capture_exception(exception)
    end
  end
end
