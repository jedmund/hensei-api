# frozen_string_literal: true

# Guards the local-only database tasks (db:restore). A shell with DATABASE_URL pointed at
# Railway once made db:restore drop production (2026-10-15), because the task drops and
# restores whatever database Rails is connected to.
module LocalDatabase
  LOCAL_HOSTS = %w[localhost 127.0.0.1 ::1].freeze

  module_function

  # A blank host (the default socket) or a socket path is local; so is a loopback host.
  def local_host?(host)
    host = host.to_s.strip
    host.empty? || host.start_with?('/') || LOCAL_HOSTS.include?(host.downcase)
  end

  # Raises unless the connection config points at this machine.
  def ensure_local!(db_config)
    config = db_config.configuration_hash
    return if local_host?(config[:host])

    raise "Refusing to restore into #{db_config.database} on #{config[:host]}: db:restore only works on a " \
          'local database. Unset DATABASE_URL (it points at a remote server) and try again.'
  end
end
