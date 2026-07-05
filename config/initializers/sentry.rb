# frozen_string_literal: true

# Sentry is only configured when a DSN is present. Skipping Sentry.init entirely
# (rather than initializing with a blank/invalid DSN) is what keeps short-lived
# processes quiet: an uninitialized SDK never installs the at_exit flush hook,
# so it can't dump transport-error backtraces to stdout.
sentry_dsn = ENV['SENTRY_DSN'].presence

# Don't initialize in one-off interactive/debug processes (console, `rails
# runner`). They install the same at_exit flush hook, which raises a noisy
# Sentry::ExternalError backtrace on any transport hiccup, and they almost never
# need error reporting. The web server, Sidekiq, and rake tasks still init
# normally. Rails loads the matching command class to dispatch the invocation
# (before initializers run), so its presence is a reliable signal; the server
# process never loads these. Set SENTRY_ENABLE_IN_CLI=true to force-enable when
# debugging Sentry itself.
one_off_process = ENV['SENTRY_ENABLE_IN_CLI'].blank? && (
  defined?(Rails::Console) ||
  defined?(Rails::Command::ConsoleCommand) ||
  defined?(Rails::Command::RunnerCommand)
)

if sentry_dsn && !one_off_process
  # Expected / user-facing exceptions that must never be reported as bugs.
  # excluded_exceptions matches subclasses, so a base class covers its leaves
  # (e.g. Api::V1::GranblueError covers FavoriteAlreadyExistsError, etc.).
  ignored_exceptions = %w[
    ActiveRecord::RecordNotFound
    ActiveRecord::RecordInvalid
    ActiveRecord::RecordNotSaved
    ActiveRecord::RecordNotDestroyed
    ActiveRecord::RecordNotUnique
    ActionController::ParameterMissing
    ActionController::RoutingError
    ActionController::UnknownFormat
    Api::V1::GranblueError
    Api::V1::UnauthorizedError
    CollectionErrors::CollectionError
    CrewErrors::CrewError
    PartyShareErrors::PartyShareError
  ].freeze

  Sentry.init do |config|
    config.dsn = sentry_dsn

    # Environment label on each event. Prefer an explicit var so Railway prod and
    # staging are distinguishable; fall back to the Rails environment.
    config.environment = ENV.fetch('SENTRY_ENVIRONMENT', Rails.env.to_s)

    # Hard gate: even if a DSN leaks into another environment, only these actually
    # transmit events.
    config.enabled_environments = %w[production staging]

    config.breadcrumbs_logger = [:active_support_logger]

    # Sample performance traces instead of sending one per request. Set the env
    # var to 0 to disable tracing entirely without a deploy.
    config.traces_sample_rate = ENV.fetch('SENTRY_TRACES_SAMPLE_RATE', '0.1').to_f

    # Drop expected / user-facing exceptions (append; the SDK pre-seeds this list
    # with framework noise, so use += rather than reassigning).
    config.excluded_exceptions += ignored_exceptions

    # Keep the SDK's own logging quiet so a transient transport error never dumps
    # an HTTPTransport backtrace to application stdout.
    config.debug = false
    if config.respond_to?(:sdk_logger)
      config.sdk_logger = Logger.new($stdout).tap { |l| l.level = Logger::WARN }
    end

    # Belt-and-suspenders: drop the same exceptions if one is wrapped/re-raised
    # under a class the excluded_exceptions ancestry check misses.
    config.before_send = lambda do |event, hint|
      exception = hint[:exception]
      next event unless exception

      dropped = ignored_exceptions.any? do |name|
        klass = name.safe_constantize
        klass && exception.is_a?(klass)
      end
      dropped ? nil : event
    end
  end
end
